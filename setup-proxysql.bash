#!/usr/bin/bash

(

./_switch-folder.bash

echo "*** Run base install"
./base/install.bash

echo "*** Install proxysql"
./install/proxysql.bash

)
