#!/bin/bash

# Installs BBB with
# -a  API Demo
# -w  Firewall
# -g  Greenlight
# -e  E-Mail Adress for LE
# -v  BBB-Version
# -s  Hostname

HOSTNAME="$(/usr/sbin/mdata-get sdc:hostname)"
EMAIL="$(/usr/sbin/mdata-get mail_adminaddr)"

if [[ $(grep -c "18.04" /etc/lsb-release) -ge 1 ]]; then
  echo "*** Install BBB 2.4 on 18.04"
  wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -w -v bionic-24 -s ${HOSTNAME} -e ${EMAIL} -g
elif [[ $(grep -c "20.04" /etc/lsb-release) -ge 1 ]]; then
  echo "*** Install BBB 2.5 on 20.04"
  wget -qO- https://ubuntu.bigbluebutton.org/bbb-install-2.5.sh | bash -s -- -w -v focal-25 -s ${HOSTNAME} -e ${EMAIL} -g
else
  echo "*** ERROR: wrong ubuntu release, skip installation"
fi

if [[ $(dpkg -l | grep -c bbb-html5) -gt 0 ]]; then
  sed -i \
    -e "s|#   ALLOW_MAIL_NOTIFICATIONS=true|ALLOW_MAIL_NOTIFICATIONS=true|" \
    -e "s|SMTP_SERVER=|SMTP_SERVER=$(/usr/sbin/mdata-get mail_smarthost)|" \
    -e "s|SMTP_PORT=|SMTP_PORT=465|" \
    -e "s|SMTP_DOMAIN=|SMTP_DOMAIN=$(/usr/sbin/mdata-get mail_smarthost | cut -d. -f2-3)|" \
    -e "s|SMTP_USERNAME=|SMTP_USERNAME=$(/usr/sbin/mdata-get mail_auth_user)|" \
    -e "s|SMTP_PASSWORD=|SMTP_PASSWORD=$(/usr/sbin/mdata-get mail_auth_pass)|" \
    -e "s|SMTP_AUTH=|SMTP_AUTH=plain|" \
    -e "s|SMTP_STARTTLS_AUTO=|SMTP_TLS=true|" \
    -e "s|SMTP_SENDER=|SMTP_SENDER=bbb@$(hostname | cut -d. -f2-3)|" \
    -e "s|SMTP_TEST_RECIPIENT=notifications@example.com|SMTP_TEST_RECIPIENT=$(/usr/sbin/mdata-get mail_adminaddr)|" \
    -e "s|HELP_URL=https://docs.bigbluebutton.org/greenlight/gl-overview.html|HELP_URL=https://qutic.com/de/kontakt/|" \
    -e "s|DEFAULT_REGISTRATION=open|DEFAULT_REGISTRATION=invite|" \
    -e "s|ALLOW_GREENLIGHT_ACCOUNTS=true|ALLOW_GREENLIGHT_ACCOUNTS=true|" \
    /root/greenlight/.env
  
  bbb-conf --restart
  docker-compose down
  docker-compose up -d
  
  bbb-conf --check
  bbb-conf --status
  
  (
    cd /root/greenlight
    NAME=$(/usr/sbin/mdata-get bbb_admin_name)
    EMAIL2=$(/usr/sbin/mdata-get bbb_admin_email)
    PWD=$(/usr/sbin/mdata-get bbb_admin_pwd)
    docker exec greenlight-v2 bundle exec rake user:create["${NAME}","${EMAIL2}","${PWD}","admin"]
  )
fi

if [[ -x /usr/local/bin/uptodate ]]; then
  cat >> /usr/local/bin/uptodate << EOF
# update the two docker images
cd /root/greenlight
docker-compose pull
docker-compose down
docker-compose up -d
EOF
fi