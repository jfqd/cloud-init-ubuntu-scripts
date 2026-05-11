!/usr/bin/bash

(

./_switch-folder.bash

echo "*** Run base install"
./base/install.bash

echo "*** Install nginx"
./install/nginx.bash

echo "*** Install bbb"
./install-onlyoffice.bash

)
