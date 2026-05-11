#!/usr/bin/bash

(

./_switch-folder.bash

echo "*** Run base install"
./base/install.bash

echo "*** Download and run fms install script"
URL="$(/usr/sbin/mdata-get fms_install_script_url)"
curl -q "${URL}" > ./install/fms.bash
chmod +x ./install/fms.bash
/usr/sbin/mdata-delete fms_install_script_url || true

./install/fms.bash

)
