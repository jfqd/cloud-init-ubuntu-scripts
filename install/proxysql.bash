#!/usr/bin/bash

echo "*** Set root pwd for ssh login"
if /usr/sbin/mdata-get ubuntu_user_secret 1>/dev/null 2>&1; then
  SECRET=$(/usr/sbin/mdata-get ubuntu_user_secret)
  /usr/sbin/usermod --password "\$6\$${SECRET}" root
fi

echo "*** Install requirements"
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade

apt-get install -y --no-install-recommends lsb-release wget apt-transport-https ca-certificates

apt-get install -y libipset13 libipset-dev mysql-client keepalived python3-pip python3-mysqldb

echo "*** Install proxysql"
wget -nv -O /etc/apt/trusted.gpg.d/proxysql-3.0.x-keyring.gpg 'https://repo.proxysql.com/ProxySQL/proxysql-3.0.x/repo_pub_key.gpg'
echo "deb https://repo.proxysql.com/ProxySQL/proxysql-3.0.x/$(lsb_release -sc)/ ./" | tee /etc/apt/sources.list.d/proxysql.list

apt-get update
apt-get -y install proxysql

if [[ -f /etc/proxysql.cnf ]]; then
  mv /etc/proxysql.cnf /etc/proxysql.cnf.bak
fi

echo "*** Install proxysql config"
if /usr/sbin/mdata-get proxysql_config_url 1>/dev/null 2>&1; then
  URL="$(/usr/sbin/mdata-get proxysql_config_url)"
  /usr/sbin/mdata-delete proxysql_config_url || true

  curl -q "${URL}" > /etc/proxysql.cnf
  chmod 0640 /etc/proxysql.cnf
  chown root:proxysql /etc/proxysql.cnf
fi

ln -nfs /var/lib/proxysql/proxysql.log /var/log/proxysql_log

service proxysql start

if /usr/sbin/mdata-get proxysql_admin_pwd 1>/dev/null 2>&1; then
  ADM_PWD="$(/usr/sbin/mdata-get proxysql_admin_pwd)"
  /usr/sbin/mdata-delete proxysql_admin_pwd || true
  cat > /root/.my.cnf << EOF
[client]
host = 127.0.0.1
port = 3307
user = admin
password = ${ADM_PWD}
prompt = 'Admin> '
EOF
fi

cat > /usr/local/bin/create_user << 'EOF'
#!/bin/bash

db_user=$1
password=$2

mysql --defaults-file=/root/.my.cnf -e "INSERT INTO mysql_users(username,password,default_hostgroup) VALUES ('${db_user}','${password}',0);"
mysql --defaults-file=/root/.my.cnf -e "LOAD MYSQL USERS TO RUNTIME;"
mysql --defaults-file=/root/.my.cnf -e "SAVE MYSQL USERS FROM RUNTIME;"
mysql --defaults-file=/root/.my.cnf -e "SAVE MYSQL USERS TO DISK;"
EOF
chmod +x /usr/local/bin/create_user

echo "*** Install failover script"
cat > /usr/local/bin/failover << 'EOF'
#!/bin/bash
SERVICE='proxysql'
STATUS=$(ps ax | grep -v grep | grep $SERVICE)

if [ "$STATUS" != "" ]
then
    exit 0
else
    exit 1
fi
EOF
chmod +x /usr/local/bin/failover

echo "*** Configure keepalived"
HOSTNAME=$(hostname)

KA_IP="$(/usr/sbin/mdata-get keepalive_vip)"
KA_RID="$(/usr/sbin/mdata-get keepalive_router_id)"
KA_VINST="$(/usr/sbin/mdata-get keepalive_instance)"
KA_PRIO="$(/usr/sbin/mdata-get keepalive_prio)"
KA_STATE="$(/usr/sbin/mdata-get keepalive_state)"
KA_PWD="$(/usr/sbin/mdata-get keepalive_password)"
KA_EMAIL="$(/usr/sbin/mdata-get mail_adminaddr)"

mkdir -p /etc/keepalived
if [[ -f /etc/keepalived/keepalived.conf ]]; then
  mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak
fi

cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
  notification_email {
    ${KA_EMAIL}
  }
  notification_email_from root@${HOSTNAME}
  smtp_server 127.0.0.1
  smtp_connect_timeout 30
  router_id VRRP-proxysql-2
}
# Script used to check if Proxy is running
vrrp_script check_proxy {
  script "/usr/local/bin/failover"
  interval 2
  weight 2
}
vrrp_instance VI_00${KA_VINST} {
  state ${KA_STATE}
  interface net0
  virtual_router_id ${KA_RID}
  priority ${KA_PRIO}
  garp_master_delay 2
  advert_int 1
  smtp_alert
  authentication {
    auth_type PASS
    auth_pass ${KA_PWD}
  }
  virtual_ipaddress {
    ${KA_IP}
  }
  track_script {
    check_proxy
  }
}
EOF
chmod 0640 /etc/keepalived/keepalived.conf
systemctl start keepalived

echo "*** Install zabbix keepalived monitoring"
cat > /usr/local/bin/zabbix_proxysql << 'EOF'
#!/usr/bin/python3
# -*- coding: utf-8
############################################################

proxysql_host     = "127.0.0.1"
proxysql_port     = 3307
proxysql_user     = "admin"
proxysql_password = "root"

############################################################

import sys
import json
import MySQLdb
import itertools

class proxysql:
	def __init__(self, proxysql_host, proxysql_port, proxysql_user, proxysql_password):
		self.__connection = MySQLdb.connect(host=proxysql_host, port=proxysql_port, user=proxysql_user, passwd=proxysql_password, db="main")
		self.__cursor = self.__connection.cursor()
	
	def __del__(self):
		self.__connection.close()

	def __select(self, sql):
		self.__cursor.execute(sql)
		#return self.__cursor.fetchall()
		field_names = [d[0].lower() for d in self.__cursor.description]
		while True:
			rows = self.__cursor.fetchmany()
			if not rows: return
			for row in rows:
				yield dict(zip(field_names, row))

	def get_servers(self):
		return self.__select("""SELECT 	`hostname`,
						`port`
					FROM `runtime_mysql_servers`
					GROUP BY `hostname`, `port`;
		""")
	def get_hostgroups(self):
		return self.__select("""SELECT	'writer' AS 'role',
						`writer_hostgroup` AS 'id'
					FROM `runtime_mysql_group_replication_hostgroups`
					UNION
					SELECT	'backup_writer' AS 'role',
						`backup_writer_hostgroup` AS 'id'
					FROM `runtime_mysql_group_replication_hostgroups`
					UNION
					SELECT	'reader' AS 'role',
						`reader_hostgroup` AS 'id'
					FROM `runtime_mysql_group_replication_hostgroups`
					UNION
					SELECT	'offline' AS 'role',
						offline_hostgroup AS 'id'
					FROM `runtime_mysql_group_replication_hostgroups`
					UNION
					SELECT  'writer' AS 'role',
						`writer_hostgroup` AS 'id'
					FROM `runtime_mysql_replication_hostgroups`
					UNION
					SELECT  'reader' AS 'role',
						`reader_hostgroup` AS 'id'
					FROM `runtime_mysql_replication_hostgroups`;
		""")
	def get_all_command_counters(self):
		return self.__select("""SELECT	`Command`,
						`Total_cnt`, 
						`cnt_100us`,
						`cnt_500us`,
						`cnt_1ms`,
						`cnt_5ms`,
						`cnt_10ms`,
						`cnt_50ms`,
						`cnt_100ms`,
						`cnt_500ms`,
						`cnt_1s`,
						`cnt_5s`,
						`cnt_10s`,
						`cnt_INFs`
					FROM `stats`.`stats_mysql_commands_counters`
					WHERE `Command` in ('COMMIT','ROLLBACK','SET','START_TRANSACTION','SELECT','INSERT','UPDATE','DELETE','SHOW_TABLE_STATUS','SHOW');
		""")

	def get_connstat_of_server(self, host, port):
		return self.__select("""SELECT	`status`,
						SUM(`ConnUsed`) AS 'connused',
						SUM(`ConnFree`) AS 'connfree',
						SUM(`ConnOK`) AS 'connok',
						SUM(`ConnERR`) AS 'connerr',
						SUM(`Queries`) AS 'queries',
						SUM(`Bytes_data_sent`) AS 'sent',
						SUM(`Bytes_data_recv`) AS 'recv',
						Latency_us
					FROM `stats`.`stats_mysql_connection_pool`
					WHERE `srv_host` = '%s' AND `srv_port` = '%s';
		""" % (host, port) )

def print_help():
	print( "\nUsage:\t%s discovery <servers|hostgroups>\n\t%s get <server|hostgroup|proxysql> [object_id]\n" % (sys.argv[0], sys.argv[0]) )

if len(sys.argv) <= 2:
	print_help()
	sys.exit(1)

pconn = proxysql(proxysql_host, proxysql_port, proxysql_user, proxysql_password)

if sys.argv[1] == 'discovery':
	discovery = {"data":[]}
	if sys.argv[2] == 'servers':
		for server in pconn.get_servers():
			discovery["data"].append({"{#SERVERNAME}":server['hostname'], "{#SERVERPORT}":server['port']})
		print( json.dumps(discovery, indent=2, sort_keys=True) )
		sys.exit(0)
	elif sys.argv[2] == 'hostgroups':
		for hostgroup in pconn.get_hostgroups():
			discovery["data"].append({"{#HOSTGROUPID}":hostgroup['id'], "{#HOSTGROUPROLE}":hostgroup['role']})
		print( json.dumps(discovery, indent=2, sort_keys=True) )
		sys.exit(0)
	else:
		print_help()
		sys.exit(1)
elif sys.argv[1] == 'get':
	if sys.argv[2] == 'proxysql':
		stats = {'commands':{}}
		for c in pconn.get_all_command_counters():
			stats['commands'][c['command']] = c
		print( json.dumps(stats, indent=2, sort_keys=True) )
	elif sys.argv[2] == 'server':
		if len(sys.argv) <= 4:
			print_help()
			sys.exit(1)
		else:
			stats = {"connstat":{}}
			for c in pconn.get_connstat_of_server(sys.argv[3], sys.argv[4]):
				stats['connstat'] = c
			print( json.dumps(stats, indent=2, sort_keys=True) )
	elif sys.argv[2] == 'hostgroup':
		if len(sys.argv) <= 3:
			print_help()
			sys.exit(1)
		else:
			print( "4" )
	else:
		print_help()
		sys.exit(1)
	sys.exit(0)
EOF
chmod 0750 /usr/local/bin/zabbix_proxysql
chown root:zabbix /usr/local/bin/zabbix_proxysql

cat > /etc/zabbix/zabbix_agentd.conf.d/proxysql.conf << 'EOF'
UserParameter=proxysql_discovery[*],/usr/local/bin/zabbix_proxysql discovery $1
UserParameter=proxysql[*],/usr/local/bin/zabbix_proxysql get $1 $2 $3
EOF

systemctl restart zabbix-agent
