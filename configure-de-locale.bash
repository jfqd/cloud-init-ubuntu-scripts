#!/usr/bin/bash

apt-get install -y language-pack-en
update-locale LANG=en_US.UTF-8
cat /etc/default/locale
