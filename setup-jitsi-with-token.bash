#!/usr/bin/bash

(

./_switch-folder.bash

./base/install.bash
./base/deactivate-ipv6.bash
./install/ufw-for-jitsi.bash
./base/configure-ufw-for-zabbix.bash
./install/jitsi-with-tokens.bash
./install/nginx.bash

)