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

echo "*** Install fms"
URL="$(/usr/sbin/mdata-get fms_install_script_url)"
curl -q "${URL}" > install-fms.bash
chmod +x install-fms.bash
/usr/sbin/mdata-delete fms_install_script_url || true
./install-fms.bash

)

# rm -rf /root/init