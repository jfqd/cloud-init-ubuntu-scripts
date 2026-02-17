#!/usr/bin/bash

export DEBIAN_FRONTEND=noninteractive

apt-get -y update

apt-get -y purge shim-signed || true

yes no | apt-get -y -qq upgrade
yes no | apt-get -y -qq dist-upgrade

apt-get clean packages
apt-get -y autoremove && apt-get autoclean
apt-get clean packages
