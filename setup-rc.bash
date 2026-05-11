#!/usr/bin/bash

(

./_switch-folder.bash

echo "*** Run base install"
./base/install.bash

echo "*** Install rc"
URL="$(/usr/sbin/mdata-get rc_install_script_url)"
curl -q "${URL}" > ./install/rc.bash
chmod +x ./install/rc.bash
/usr/sbin/mdata-delete rc_install_script_url || true

./install/rc.bash

)
