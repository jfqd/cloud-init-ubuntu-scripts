#!/bin/bash

(

cd $(dirname $(readlink -f $0))

./base-install.bash

echo "*** Deactivate ipv6"
./deactivate-ipv6.bash

echo "*** Setup ufw"
./install-ufw-for-jitsi.bash
./configure-ufw-for-zabbix.bash

echo "*** Install jitsi"
./install-jitsi-with-pwd.bash

echo "*** Install nginx"
./install-nginx.bash

)