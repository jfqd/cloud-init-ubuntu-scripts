#!/bin/bash

echo 'APT::Periodic::Enable 0;' > /etc/apt/apt.conf.d/10cloudinit-disable
apt-get -y purge update-notifier-common ubuntu-release-upgrader-core landscape-common unattended-upgrades
rm -rf /var/log/unattended-upgrades
apt-get -y autoremove
