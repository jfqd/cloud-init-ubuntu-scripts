#!/usr/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "*** Set hostname"
./base/set-hostname.bash

echo "*** Update ubuntu user"
./base/configure-user-secret.bash

echo "*** Get latest upgrades"
./base/fix-shim-config.bash
./base/apt-upgrade.bash

echo "*** Install exim"
./install/exim4.bash

echo "*** Install zabbix"
./install/zabbix-agent.bash

echo "*** Harden sshd config"
./base/harden_sshd.bash