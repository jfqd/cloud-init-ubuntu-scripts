#!/bin/bash

path=$(realpath $0)
folder=$(dirname "$path")

echo "*** Switch to folder: ${folder}"
cd "${folder}"

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
