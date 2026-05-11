#!/usr/bin/bash

(

path=$(realpath $0)
folder=$(dirname "$path")

echo "*** Switch to folder: ${folder}"
cd "${folder}"

./base/install.bash
./base/deactivate-ipv6.bash
./install/ufw-for-jitsi.bash
./base/configure-ufw-for-zabbix.bash
./install/jitsi-with-tokens.bash
./install/nginx.bash

)