#!/bin/bash

(

cd $(dirname $(readlink -f $0))

./base-install.bash
./deactivate-ipv6.bash
./install-uwf-for-jitsi.bash
./configure-uwf-for-zabbix.bash
./install-jitsi-with-tokens.bash
./install-nginx.bash

)