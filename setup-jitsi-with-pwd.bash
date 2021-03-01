#!/bin/bash

(

cd $(dirname $(readlink -f $0))

./install-exim4.bash
./base-install.bash
./deactivate-ipv6.bash
./install-uwf-for-jitsi.bash
./configure-uwf-for-zabbix.bash
./install-nginx.bash
./install-jitsi-with-pwd.bash

)