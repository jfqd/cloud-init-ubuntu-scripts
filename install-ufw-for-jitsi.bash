#!/bin/bash

apt-get -y -qq install ufw

ufw deny incoming
ufw allow outgoing
ufw allow in ssh
ufw allow in http
ufw allow in https
ufw allow in 3478
ufw allow in 5349
ufw allow in 10000:20000/udp
ufw enable
yes | ufw --force enable
yes | ufw --force enable
