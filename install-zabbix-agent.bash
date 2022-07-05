#!/bin/bash

if [[ $(grep -c "18.04" /etc/lsb-release) -ge 1 ]]; then
  echo "*** Install zabbix-agent on 18.04"
  wget https://repo.zabbix.com/zabbix/4.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.0-3+bionic_all.deb
  dpkg -i zabbix-release_4.0-3+bionic_all.deb
  rm zabbix-release_4.0-3+bionic_all.deb
elif [[ $(grep -c "20.04" /etc/lsb-release) -ge 1 ]]; then
  echo "*** Install zabbix-agent on 20.04"
  wget https://repo.zabbix.com/zabbix/4.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.0-3+focal_all.deb
  dpkg -i zabbix-release_4.0-3+focal_all.deb
  rm zabbix-release_4.0-3+focal_all.deb
else
  echo "*** ERROR: wrong ubuntu release, skip zabbix installation"
  exit 1
fi

# apt-get -y update
# apt-get -y install zabbix-agent
mkdir -p /var/log/zabbix
chown zabbix:zabbix /var/log/zabbix
mkdir -p /etc/zabbix/zabbix_agentd.conf.d

if mdata-get zabbix_pski 1>/dev/null 2>&1; then
  PSKI=$(/usr/sbin/mdata-get zabbix_pski)
  if mdata-get zabbix_psk 1>/dev/null 2>&1; then
    PSK=$(/usr/sbin/mdata-get zabbix_psk)
    echo "${PSK}" > /etc/zabbix/zabbix_agentd.psk
    chmod 0400 /etc/zabbix/zabbix_agentd.psk
    chown zabbix:zabbix /etc/zabbix/zabbix_agentd.psk
    sed -i \
        -e "s|# TLSAccept=unencrypted|TLSAccept=psk|" \
        -e "s|# TLSConnect=unencrypted|TLSConnect=psk|" \
        -e "s|# TLSPSKIdentity=|TLSPSKIdentity=${PSKI}|" \
        -e "s|# TLSPSKFile=|TLSPSKFile=/etc/zabbix/zabbix_agentd.psk|" \
        /etc/zabbix/zabbix_agentd.conf
  fi
fi

if mdata-get zabbix_server 1>/dev/null 2>&1; then
  ZABBIX_SERVER=$(/usr/sbin/mdata-get zabbix_server)
  sed -i \
      -e "s|Server=127.0.0.1|Server=${ZABBIX_SERVER}|" \
      -e "s|ServerActive=127.0.0.1|ServerActive=${ZABBIX_SERVER}|" \
      /etc/zabbix/zabbix_agentd.conf

  HOSTNAME=$(/bin/hostname)
  sed -i \
      -e "s|LogFile=/tmp/zabbix_agentd.log|LogFile=/var/log/zabbix/zabbix_agentd.log|" \
      -e "s|Hostname=Zabbix server|Hostname=${HOSTNAME}|" \
      /etc/zabbix/zabbix_agentd.conf

  systemctl restart zabbix-agent
  systemctl enable zabbix-agent
fi
