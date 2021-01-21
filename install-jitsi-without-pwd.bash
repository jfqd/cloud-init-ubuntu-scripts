#!/bin/bash

sed -i "s/#DefaultLimitNOFILE=/DefaultLimitNOFILE=65000/" /etc/systemd/system.conf
sed -i "s/#DefaultLimitNPROC=/DefaultLimitNPROC=65000/" /etc/systemd/system.conf
sed -i "s/#DefaultTasksMax=/DefaultTasksMax=65000/" /etc/systemd/system.conf

curl -Ls https://download.jitsi.org/jitsi-key.gpg.key | apt-key add -
echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list
apt-get -y update

# https://github.com/jitsi/jitsi-meet/issues/5759
echo "jitsi-videobridge jitsi-videobridge/jvb-hostname string ${HOSTNAME}" | debconf-set-selections
echo "jitsi-meet-web-config jitsi-meet/cert-choice select 'Generate a new self-signed certificate (You will later get a chance to obtain a Let's encrypt certificate)'" | debconf-set-selections
apt-get --option=Dpkg::Options::=--force-confold --option=Dpkg::options::=--force-unsafe-io --assume-yes --quiet install jitsi-meet

# report@qutic.com
sed -i 's|read EMAIL|EMAIL=$(/usr/sbin/mdata-get mail_adminaddr)|' /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
/usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

# activate private rest endpoint
sed -i -e "s|JVB_OPTS=\"--apis=.\"|JVB_OPTS=\"--apis=rest\"|" /etc/jitsi/videobridge/config

rm /etc/jitsi/videobridge/jvb.conf
cat /etc/jitsi/videobridge/jvb.conf << EOF
videobridge {
    http-servers {
        public {
            port = 9090
        }
        private {
            port = 8080
            tls-port = -1
            host = localhost
        }
    }
    websockets {
        enabled = true
        domain = "jitsi.example.com:443"
        tls = true
    }
}
EOF
sed -i -e "s/jitsi.example.com/${HOSTNAME}/" /etc/jitsi/videobridge/jvb.conf

# zabbix monitoring
cat >> /etc/zabbix/zabbix_agentd.d/local.conf << EOF
UserParameter=jitsi.stats,curl -s "http://localhost:8080/colibri/stats"
EOF
systemctl restart zabbix-agent
