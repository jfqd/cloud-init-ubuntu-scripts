#!/usr/bin/bash

(

./_switch-folder.bash

echo "*** Run base install"
./base/install.bash

echo "*** Configure locale"
./base/configure-de-locale.bash

echo "*** Increase disk size"
./base/deactivate-ipv6.bash

echo "*** Install nginx"
./install/nginx.bash

echo "*** Install bbb"
./install/bbb.bash

echo "*** Allow zabbix"
./base/configure-ufw-for-zabbix.bash

)
