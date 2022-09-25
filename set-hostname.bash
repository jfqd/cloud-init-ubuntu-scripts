#!/bin/bash

IP=$(ip address show dev net0 | grep 'inet ' | awk '{print $2}' | sed 's|/.*||')
HOSTNAME=$(/usr/sbin/mdata-get sdc:hostname)
echo "${IP}  ${HOSTNAME}" >> /etc/hosts
sed -i "s/preserve_hostname: false/preserve_hostname: true/" /etc/cloud/cloud.cfg
hostnamectl set-hostname $HOSTNAME
