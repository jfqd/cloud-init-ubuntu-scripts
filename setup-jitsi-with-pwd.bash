#!/usr/bin/bash

(

path=$(realpath $0)
folder=$(dirname "$path")

echo "*** Switch to folder: ${folder}"
cd "${folder}"

./base/install.bash

echo "*** Deactivate ipv6"
./base/deactivate-ipv6.bash

echo "*** Setup ufw"
./install/ufw-for-jitsi.bash
./base/configure-ufw-for-zabbix.bash

echo "*** Install jitsi"
./install/jitsi-with-pwd.bash

echo "*** Install nginx"
./install/nginx.bash

)