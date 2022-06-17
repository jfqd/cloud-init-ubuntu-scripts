#!/bin/bash

(

path=$(realpath $0)

echo "*** Switch to folder: $path"
cd "$(dirname "$path")"

echo "*** Run base install"
./base-install.bash

echo "*** Configure locale"
./configure-de-locale.bash

echo "*** Increase disk size"
./increase-disk.bash

echo "*** Install nginx"
./install-nginx.bash

echo "*** Install bbb"
./install-bbb.bash

echo "*** Allow zabbix"
./configure-uwf-for-zabbix.bash

)
