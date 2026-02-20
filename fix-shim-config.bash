#!/usr/bin/bash

LINE_NUMBER=$(grep -n "/boot/efi was on" /etc/fstab | cut -d: -f1)
NEXT_LINE=$(($LINE_NUMBER +1))
DISK_PATH=$(head -n ${NEXT_LINE} /etc/fstab |tail -n 1 |awk '{print $1}')

if [[ -n $(echo $DISK_PATH |grep by-uuid) ]]; then
  echo "grub-efi-amd64 grub-efi/install_devices multiselect ${DISK_PATH}" | debconf-set-selections
fi