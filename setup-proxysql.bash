#!/usr/bin/bash

(

path=$(realpath $0)
folder=$(dirname "$path")

echo "*** Switch to folder: ${folder}"
cd "${folder}"

echo "*** Run base install"
./base/install.bash

echo "*** Install proxysql"
./install/proxysql.bash

)
