#!/bin/bash

swapoff -a || true
sed -i -e "s|/dev/vda2|#/dev/vda2|" /etc/fstab
parted -s /dev/vda rm 2 || true
growpart /dev/vda 1 || true
resize2fs /dev/vda1 || true