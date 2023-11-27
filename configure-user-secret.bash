#!/bin/bash

if [[ "$(id ubuntu 2>/dev/null; echo $?)" = "1" ]]; then
  addgroup ubuntu
  adduser --disabled-password --system --quiet --home /home/ubuntu --shell /usr/bin/bash ubuntu
  usermod -G ubuntu,sudo ubuntu
  mkdir -p /home/ubuntu
fi

if /usr/sbin/mdata-get ubuntu_user_secret 1>/dev/null 2>&1; then
  SECRET=$(/usr/sbin/mdata-get ubuntu_user_secret)
  /usr/sbin/usermod --password "\$6\$${SECRET}" ubuntu
fi
