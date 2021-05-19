#!/bin/bash

path=$(realpath $0)

echo "*** Switch to folder: $path"
cd "$(dirname "$path")"

export DEBIAN_FRONTEND=noninteractive

echo "*** Set hostname"
./set-hostname.bash

echo "*** Get latest upgrades"
./apt-upgrade.bash

echo "*** Install exim"
./install-exim4.bash

echo "*** Update ubuntu user"
if /usr/sbin/mdata-get ubuntu_user_secret 1>/dev/null 2>&1; then
  SECRET=$(/usr/sbin/mdata-get ubuntu_user_secret)
  /usr/sbin/usermod --password "$6\$.${SECRET}" ubuntu
fi

echo "*** Install zabbix"
./install-zabbix-agent.bash
