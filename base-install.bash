#!/bin/bash

path=$(realpath $0)
cd "$(dirname "$path")"

./apt-upgrade.bash
./install-exim4.bash
./install-zabbix-agent.bash
