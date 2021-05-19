#!/bin/bash

path=$(realpath $0)

echo "*** Switch to folder: $path"
cd "$(dirname "$path")"

export DEBIAN_FRONTEND=noninteractive

echo "*** Set hostname"
./set-hostname.bash

echo "*** Update ubuntu user"
./configure-user-secret.bash

echo "*** Get latest upgrades"
./apt-upgrade.bash

echo "*** Install exim"
./install-exim4.bash

echo "*** Install zabbix"
./install-zabbix-agent.bash
