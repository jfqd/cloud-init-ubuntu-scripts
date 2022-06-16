#!/bin/bash


echo "*** Configure locale"
./configure-de-locale.bash

echo "*** Install bbb"
./install-bbb.bash

echo "*** Allow zabbix"
./configure-uwf-for-zabbix.bash

echo "*** Increase disk size"
./increase-disk.bash

# should reboot