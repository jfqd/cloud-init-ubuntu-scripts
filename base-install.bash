#!/bin/bash

path=$(realpath $0)
cd "$(dirname "$path")"

./set-hostname.bash
./apt-upgrade.bash
./install-exim4.bash
./install-zabbix-agent.bash
