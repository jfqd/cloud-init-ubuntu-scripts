#!/bin/bash

(

cd $(dirname $(readlink -f $0))

./base-install.bash

echo "*** Deactivate ipv6"
./deactivate-ipv6.bash

echo "*** Setup uwf"
./install-uwf-for-jitsi.bash
./configure-uwf-for-zabbix.bash

echo "*** Install jitsi"
./install-jitsi-with-pwd.bash

echo "*** Install nginx"
./install-nginx.bash

)