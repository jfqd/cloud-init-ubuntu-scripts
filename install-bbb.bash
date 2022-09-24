#!/bin/bash

# Installs BBB with
# -a  API Demo
# -w  Firewall
# -g  Greenlight
# -e  E-Mail Adress for LE
# -v  BBB-Version
# -s  Hostname

HOSTNAME="$(/usr/sbin/mdata-get sdc:hostname 2>/dev/null)"
EMAIL="$(/usr/sbin/mdata-get mail_adminaddr 2>/dev/null)"

if [[ $(grep -c "18.04" /etc/lsb-release) -ge 1 ]]; then
  echo "*** Install BBB 2.4 on 18.04"
  wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -w -v bionic-24 -s ${HOSTNAME} -e ${EMAIL} -g
elif [[ $(grep -c "20.04" /etc/lsb-release) -ge 1 ]]; then
  echo "*** Install BBB 2.5 on 20.04"
  wget -qO- https://ubuntu.bigbluebutton.org/bbb-install-2.5.sh | bash -s -- -w -v focal-250 -s ${HOSTNAME} -e ${EMAIL} -g
else
  echo "*** ERROR: wrong ubuntu release, skip installation"
  exit 1
fi

if [[ $(dpkg -l | grep -c bbb-html5) -gt 0 ]]; then
  
  COTURN_SECRET=$(/usr/sbin/mdata-get coturn_secret 2>/dev/null)
  COTURN_HOST=$(/usr/sbin/mdata-get coturn_host 2>/dev/null)
  COTURN_PORT=$(/usr/sbin/mdata-get coturn_port 2>/dev/null)
  
  if [[ -n $COTURN_SECRET && -n $COTURN_HOST && -n $COTURN_PORT ]]; then
    echo "*** Configure STUN- and TURN-server"
    cp /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml \
      /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml.orig
  
    cat > /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.springframework.org/schema/beans
        http://www.springframework.org/schema/beans/spring-beans-2.5.xsd">

    <bean id="stun0" class="org.bigbluebutton.web.services.turn.StunServer">
        <constructor-arg index="0" value="stun:${COTURN_HOST}"/>
    </bean>


    <bean id="turn0" class="org.bigbluebutton.web.services.turn.TurnServer">
        <constructor-arg index="0" value="${COTURN_SECRET}"/>
        <constructor-arg index="1" value="turns:${COTURN_HOST}:${COTURN_PORT}?transport=tcp"/>
        <constructor-arg index="2" value="86400"/>
    </bean>

    <bean id="stunTurnService"
            class="org.bigbluebutton.web.services.turn.StunTurnService">
        <property name="stunServers">
            <set>
                <ref bean="stun0"/>
            </set>
        </property>
        <property name="turnServers">
            <set>
                <ref bean="turn0"/>
            </set>
        </property>
    </bean>
</beans>
EOF
  cp /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml \
    /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml.bak
  
  else
    echo "*** No STUN- and TURN-server cause of missing configaration"
  fi
  
  # OIDC config
  if [[ -n "$(/usr/sbin/mdata-get bbb_oicd_client_id 2>/dev/null)" ]]; then
    echo "*** Get OIDC config"
    BBB_OICD_CLIENT_ID=$(/usr/sbin/mdata-get bbb_oicd_client_id 2>/dev/null)
    BBB_OICD_CLIENT_SECRET=$(/usr/sbin/mdata-get bbb_oicd_client_secret 2>/dev/null)
    BBB_OICD_ISSUER=$(/usr/sbin/mdata-get bbb_oicd_issuer 2>/dev/null)
    BBB_OICD_REDIRECT=$(/usr/sbin/mdata-get bbb_oicd_redirect 2>/dev/null)

    if [[ -z "${BBB_OICD_REDIRECT}" ]]; then
      BBB_OICD_REDIRECT="${HOSTNAME}/b"
    fi
  fi
  
  if [[ -n "$(/usr/sbin/mdata-get bbb_allow_accounts 2>/dev/null)" ]]; then
    ALLOW_GREENLIGHT_ACCOUNTS="$(/usr/sbin/mdata-get bbb_allow_accounts 2>/dev/null)"
  else
    ALLOW_GREENLIGHT_ACCOUNTS="true"
  fi
  
  if [[ -n "$(/usr/sbin/mdata-get bbb_registration 2>/dev/null)" ]]; then
    DEFAULT_REGISTRATION="$(/usr/sbin/mdata-get bbb_registration 2>/dev/null)"
  else
    DEFAULT_REGISTRATION="invite"
  fi

  echo "*** Configure greenlight"
  sed -i \
    -e "s|#   ALLOW_MAIL_NOTIFICATIONS=true|ALLOW_MAIL_NOTIFICATIONS=true|" \
    -e "s|SMTP_SERVER=|SMTP_SERVER=$(/usr/sbin/mdata-get mail_smarthost 2>/dev/null)|" \
    -e "s|SMTP_PORT=|SMTP_PORT=465|" \
    -e "s|SMTP_DOMAIN=|SMTP_DOMAIN=$(/usr/sbin/mdata-get mail_smarthost 2>/dev/null | cut -d. -f2-3)|" \
    -e "s|SMTP_USERNAME=|SMTP_USERNAME=$(/usr/sbin/mdata-get mail_auth_user 2>/dev/null)|" \
    -e "s|SMTP_PASSWORD=|SMTP_PASSWORD=$(/usr/sbin/mdata-get mail_auth_pass 2>/dev/null)|" \
    -e "s|SMTP_AUTH=|SMTP_AUTH=plain|" \
    -e "s|SMTP_STARTTLS_AUTO=|SMTP_TLS=true|" \
    -e "s|SMTP_SENDER=|SMTP_SENDER=bbb@$(hostname | cut -d. -f2-3)|" \
    -e "s|SMTP_TEST_RECIPIENT=notifications@example.com|SMTP_TEST_RECIPIENT=$(/usr/sbin/mdata-get mail_adminaddr 2>/dev/null)|" \
    -e "s|HELP_URL=https://docs.bigbluebutton.org/greenlight/gl-overview.html|HELP_URL=https://qutic.com/de/kontakt/|" \
    -e "s|DEFAULT_REGISTRATION=open|DEFAULT_REGISTRATION=${DEFAULT_REGISTRATION}|" \
    -e "s|ALLOW_GREENLIGHT_ACCOUNTS=true|ALLOW_GREENLIGHT_ACCOUNTS=${ALLOW_GREENLIGHT_ACCOUNTS}|" \
    -e "s|OPENID_CONNECT_CLIENT_ID=|OPENID_CONNECT_CLIENT_ID=${BBB_OICD_CLIENT_ID}|" \
    -e "s|OPENID_CONNECT_CLIENT_SECRET=|OPENID_CONNECT_CLIENT_SECRET=${BBB_OICD_CLIENT_SECRET}|" \
    -e "s|OPENID_CONNECT_ISSUER=|OPENID_CONNECT_ISSUER=${BBB_OICD_ISSUER}|" \
    -e "s|OAUTH2_REDIRECT=|OAUTH2_REDIRECT=${BBB_OICD_REDIRECT}|" \
    /root/greenlight/.env
  
  # ensure hostname for recordings
  bbb-conf --setip "${HOSTNAME}"
  
  bbb-conf --restart
  docker-compose down
  docker-compose up -d
  
  bbb-conf --check
  bbb-conf --status
  
  echo "*** Create greenlight admin account"
  (
    cd /root/greenlight
    NAME=$(/usr/sbin/mdata-get bbb_admin_name 2>/dev/null)
    EMAIL2=$(/usr/sbin/mdata-get bbb_admin_email 2>/dev/null)
    PWD=$(/usr/sbin/mdata-get bbb_admin_pwd 2>/dev/null)
    docker exec greenlight-v2 bundle exec rake user:create["${NAME}","${EMAIL2}","${PWD}","admin"]
    
    docker-compose pull
    docker-compose down
    docker-compose up -d
  )
else
  echo "*** ERROR: BigBlueButton installation failed"
  exit 1
fi

echo "*** Configure bbb monitoring"
(
  cd /root/
  git clone https://github.com/jfqd/bbbstats.git
  mkdir /etc/bbbstats
  cp ./bbbstats/config.example.json /etc/bbbstats/config.json
  cp ./bbbstats/bbbstats.py /usr/bin/bbbstats
  cp ./bbbstats/bbbstats.conf /etc/zabbix/zabbix_agentd.d/bbstats.conf
  URL=$(bbb-conf --secret | grep "URL: " | awk '{print $2}')
  SECRET=$(bbb-conf --secret | grep "Secret: " | awk '{print $2}')
  sed -i \
      -e "s|https://bbb.example.com/bigbluebutton/api/|${URL}api/|" \
      -e "s|your_api_secret|${SECRET}|" /etc/bbbstats/config.json
  chown zabbix /usr/bin/bbbstats
  chmod u+x /usr/bin/bbbstats
  chown -R zabbix /etc/bbbstats
  chmod 400 /etc/bbbstats/config.json
  chmod 500 /etc/bbbstats/
  rm -rf /root/bbbstats
  systemctl restart zabbix-agent
)

echo "*** Configure ssh ufw"
ufw delete allow OpenSSH
ufw allow from 91.229.246.24/32 to any port 22 proto tcp
ufw allow from 91.229.246.25/32 to any port 22 proto tcp

echo "*** Configure bbr"
# https://wiki.crowncloud.net/?How_to_enable_BBR_on_Debian_10
cat >> /etc/sysctl.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p

echo "*** Get Meeting-Details"
/usr/bin/apt-get -y install net-tools python3-pip
pip3 install bigbluebutton_api_python
pip3 install pyyaml
curl -LO https://raw.githubusercontent.com/aau-zid/BigBlueButton-liveStreaming/master/examples/get_meetings.py
chmod 0700 get_meetings.py

echo "*** Configure scripts"
cat > /usr/local/bin/uptodate << 'EOF'
#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  SUDO="sudo -E"
else
  SUDO=""
fi

export DEBIAN_FRONTEND=noninteractive
$SUDO /usr/bin/apt-get update
$SUDO /usr/bin/apt-get -y -o Dpkg::Options::="--force-confold" upgrade
$SUDO /usr/bin/apt-get -y -o Dpkg::Options::="--force-confold" dist-upgrade
$SUDO /usr/bin/apt-get -y autoremove

$SUDO /usr/bin/cp /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml.bak \
  /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml

# update the docker images
$SUDO /usr/local/bin/uptodate-greenlight

$SUDO sed -i \
  -e \"s|proxy_pass http://91.229.246.61:5066;|proxy_pass https://91.229.246.61:7443;|" \
  /usr/share/bigbluebutton/nginx/sip.nginx

$SUDO /usr/bin/bbb-conf --restart

$SUDO ufw delete allow OpenSSH
EOF
chmod +x /usr/local/bin/uptodate

cat > /usr/local/bin/uptodate-greenlight << EOF
#!/bin/bash

# update the docker images
cd /root/greenlight
docker-compose pull
docker-compose down
docker-compose up -d
EOF
chmod +x /usr/local/bin/uptodate-greenlight

cat > /root/.bash_history << EOF
tail -f /var/log/syslog
vim /root/greenlight/.env
cd /root/greenlight && docker-compose down && docker-compose up -d
systemctl restart nginx
/usr/local/bin/uptodate
bbb-conf --check
bbb-conf --status
bbb-conf --restart
ufw status verbose
ufw status numbered
tail -f /var/log/ufw.log
tail -f /var/log/syslog
tail -f /var/log/cloud-init*
bbb-conf --status
EOF
