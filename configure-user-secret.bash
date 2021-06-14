#!/bin/bash

if /usr/sbin/mdata-get ubuntu_user_secret 1>/dev/null 2>&1; then
  SECRET=$(/usr/sbin/mdata-get ubuntu_user_secret)
  /usr/sbin/usermod --password "\$6\$${SECRET}" ubuntu
fi
