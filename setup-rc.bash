#!/bin/bash

(

path=$(realpath $0)
folder=$(dirname "$path")

echo "*** Switch to folder: ${folder}"
cd "${folder}"

echo "*** Run base install"
./base-install.bash

echo "*** Configure locale"
./configure-de-locale.bash

# echo "*** Increase disk size"
# ./increase-disk.bash

echo "*** Install rc"
URL="$(/usr/sbin/mdata-get rc_install_script_url)"
curl -q "${URL}" > install-rc.bash
chmod +x install-rc.bash
/usr/sbin/mdata-delete rc_install_script_url || true
./install-rc.bash

)

rm -rf /root/init