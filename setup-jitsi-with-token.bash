#!/bin/bash

(

cd $(dirname $(readlink -f $0))

./base-install.bash
./deactivate-ipv6.bash
./install-ufw-for-jitsi.bash
./configure-ufw-for-zabbix.bash
./install-jitsi-with-tokens.bash
./install-nginx.bash

)