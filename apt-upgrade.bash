#!/bin/bash

apt-get -y update
yes no | apt-get -y -qq upgrade
apt-get -y -qq dist-upgrade
