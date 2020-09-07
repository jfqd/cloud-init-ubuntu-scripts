#!/bin/bash

apt -y -qq install exim4 apt-transport-https

if /usr/sbin/mdata-get mail_smarthost 1>/dev/null 2>&1; then
  if /usr/sbin/mdata-get mail_adminaddr 1>/dev/null 2>&1; then
    echo "root: $(/usr/sbin/mdata-get mail_adminaddr)" >> /etc/aliases
    newaliases
  fi
  AUTH=""
  if /usr/sbin/mdata-get mail_auth_user 1>/dev/null 2>&1 && 
     /usr/sbin/mdata-get mail_auth_pass 1>/dev/null 2>&1; then
    AUTH="$(/usr/sbin/mdata-get mail_auth_user):$(/usr/sbin/mdata-get mail_auth_pass)"
  fi
  echo "$(/usr/sbin/mdata-get mail_smarthost):$AUTH" > /etc/exim4/passwd.client
  chmod 0640 /etc/exim4/passwd.client
  
  sed -i "s:dc_eximconfig_configtype='local':dc_eximconfig_configtype='satellite':" \
    /etc/exim4/update-exim4.conf.conf

  sed -i "s:dc_smarthost='':dc_smarthost='$(/usr/sbin/mdata-get mail_smarthost)':" \
    /etc/exim4/update-exim4.conf.conf
fi

sed -i "s:dc_other_hostnames='localhost':dc_other_hostnames='$(/bin/echo -n `/bin/hostname -f`)':" \
  /etc/exim4/update-exim4.conf.conf

hostname > /etc/mailname
service exim4 restart
