!/usr/bin/bash

(

path=$(realpath $0)
folder=$(dirname "$path")

echo "*** Switch to folder: ${folder}"
cd "${folder}"

echo "*** Run base install"
./base/install.bash

echo "*** Install nginx"
./install/nginx.bash

echo "*** Install onlyoffice"
./install/onlyoffice.bash

)
