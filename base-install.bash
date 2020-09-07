#!/bin/bash

path=$(realpath $0)

echo "switch to folder: $path"
cd "$(dirname "$path")"

export DEBIAN_FRONTEND=noninteractive

echo "set hostname"
./set-hostname.bash

# echo "remove unattended-upgrades"
# ./apt-config.bash

echo "get latest upgrades"
./apt-upgrade.bash

echo "install exim"
./install-exim4.bash

echo "install zabbix"
./install-zabbix-agent.bash
