#!/bin/bash

apt -y -qq install ufw

ufw allow in ssh
ufw allow in http
ufw allow in https
ufw allow in 10000:20000/udp
ufw active
yes | ufw enable
yes | ufw enable
