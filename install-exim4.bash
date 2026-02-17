#!/usr/bin/bash

apt-get -y -qq install exim4 apt-transport-https

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
  
  sed -i "s:dc_eximconfig_configtype='local':dc_eximconfig_configtype='smarthost':" \
    /etc/exim4/update-exim4.conf.conf
  
  sed -i "s|dc_local_interfaces='127.0.0.1 ; ::1'|dc_local_interfaces='127.0.0.1'|" \
    /etc/exim4/update-exim4.conf.conf

  sed -i "s|dc_smarthost=''|dc_smarthost='$(/usr/sbin/mdata-get mail_smarthost)'::587|" \
    /etc/exim4/update-exim4.conf.conf
fi

echo "disable_ipv6='true'" >> /etc/exim4/update-exim4.conf.conf

HOSTNAME=$(/bin/echo -n `/bin/hostname`)
sed -i "s:dc_other_hostnames='localhost':dc_other_hostnames='${HOSTNAME}':" \
  /etc/exim4/update-exim4.conf.conf

hostname > /etc/mailname

update-exim4.conf

systemctl stop exim4
systemctl start exim4
