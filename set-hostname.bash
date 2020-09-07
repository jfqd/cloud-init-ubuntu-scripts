#!/bin/bash

HOSTNAME=$(/usr/sbin/mdata-get sdc:hostname)
sed -i "s/127.0.0.1 localhost/127.0.0.1 localhost $(hostname) ${HOSTNAME}/" /etc/hosts
sed -i "s/preserve_hostname: false/preserve_hostname: true/" /etc/cloud/cloud.cfg
hostnamectl set-hostname $HOSTNAME
