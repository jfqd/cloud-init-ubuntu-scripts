#!/bin/bash

# https://szewong.medium.com/rocket-chat-part-3-installing-jitsi-with-jwt-for-secure-video-conferencing-b6f909e7f92c
# https://community.jitsi.org/t/solved-issue-in-connectivity-after-upgrade-the-jitsi-meet/17882/6

HOSTNAME=$(/usr/sbin/mdata-get sdc:hostname)
EMAIL=$(/usr/sbin/mdata-get mail_adminaddr)
APP_ID=$(echo "${HOSTNAME}" | cut -d"." -f1)

if /usr/sbin/mdata-get jitsi_app_secret 1>/dev/null 2>&1; then
  APP_SECRET=$(/usr/sbin/mdata-get jitsi_app_secret)
else
  APP_SECRET=$(hexdump -n 16 -e '4/4 "%08X" 1 "\n"' /dev/urandom)
fi

sed -i "s/#DefaultLimitNOFILE=/DefaultLimitNOFILE=65000/" /etc/systemd/system.conf
sed -i "s/#DefaultLimitNPROC=/DefaultLimitNPROC=65000/" /etc/systemd/system.conf
sed -i "s/#DefaultTasksMax=/DefaultTasksMax=65000/" /etc/systemd/system.conf

echo deb http://packages.prosody.im/debian $(lsb_release -sc) main | tee -a /etc/apt/sources.list
wget https://prosody.im/files/prosody-debian-packages.key -O- | apt-key add -
apt-get update
apt-get -y -qq install prosody

curl -Ls https://download.jitsi.org/jitsi-key.gpg.key | apt-key add -
echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list
apt-get update

# https://github.com/jitsi/jitsi-meet/issues/5759
echo "jitsi-videobridge jitsi-videobridge/jvb-hostname string ${HOSTNAME}" | debconf-set-selections
echo "jitsi-meet-web-config jitsi-meet/cert-choice select 'Generate a new self-signed certificate (You will later get a chance to obtain a Let's encrypt certificate)'" | debconf-set-selections
apt-get --option=Dpkg::Options::=--force-confold --option=Dpkg::options::=--force-unsafe-io --assume-yes --quiet install jitsi-meet

sed -i "s|read EMAIL|EMAIL=${EMAIL}|" /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
/usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

echo "jitsi-meet-tokens jitsi-meet-tokens/appid string ${APP_ID}" | debconf-set-selections
echo "jitsi-meet-tokens jitsi-meet-tokens/appsecret string ${APP_SECRET}" | debconf-set-selections
apt-get -y install gcc unzip libsasl2-dev lua5.2 liblua5.2 liblua5.2-dev luarocks libssl1.0-dev

# install lua libs
luarocks install luacrypto
apt-get --option=Dpkg::Options::=--force-confold --option=Dpkg::options::=--force-unsafe-io --assume-yes --quiet install jitsi-meet-tokens
luarocks remove --force lua-cjson

# fix lua-cjson
(
cd
luarocks download lua-cjson
luarocks unpack lua-cjson-2.1.0.6-1.src.rock
cd lua-cjson-2.1.0.6-1/lua-cjson
sed -i "s/lua_objlen/lua_rawlen/g" lua_cjson.c
sed -i 's|$(PREFIX)/include|/usr/include/lua5.2|g' Makefile
luarocks make
)
luarocks install luajwtjitsi
luarocks install cyrussasl 1.1.0-1
luarocks install net-url 0.9-1

# strange, but the second time it installs more packages...
apt-get -y purge jitsi-meet-tokens
echo "jitsi-meet-tokens jitsi-meet-tokens/appid string ${APP_ID}" | debconf-set-selections
echo "jitsi-meet-tokens jitsi-meet-tokens/appsecret string ${APP_SECRET}" | debconf-set-selections
apt-get --option=Dpkg::Options::=--force-confold --option=Dpkg::options::=--force-unsafe-io --assume-yes --quiet install jitsi-meet-tokens

cp /etc/prosody/conf.avail/${HOSTNAME}.cfg.lua /etc/prosody/conf.avail/${HOSTNAME}.cfg.lua.orig
cat >> /etc/prosody/conf.avail/${HOSTNAME}.cfg.lua << EOF

VirtualHost "guest.${HOSTNAME}"
    authentication = "token"
    c2s_require_encryption = true
    app_id="${APP_ID}"
    app_secret="${APP_SECRET}"
EOF

sed -i "s#storage = \"none\"#storage = \"memory\"#g" /etc/prosody/conf.avail/${HOSTNAME}.cfg.lua
sed -i "s|\"external_services\";|\"external_services\";\n        \"presence_identity\";|" /etc/prosody/conf.avail/${HOSTNAME}.cfg.lua

sed -i "s#// anonymousdomain: 'guest.example.com',#anonymousdomain: 'guest.${HOSTNAME}',#" /etc/jitsi/meet/${HOSTNAME}-config.js

echo "org.jitsi.jicofo.auth.URL=XMPP:${HOSTNAME}" >> /etc/jitsi/jicofo/sip-communicator.properties

# activate private rest endpoint
sed -i -e "s|JVB_OPTS=\"--apis=.\"|JVB_OPTS=\"--apis=rest\"|" /etc/jitsi/videobridge/config

cat >> /etc/prosody/prosody.cfg.lua << EOF

component_ports = { 5347 }
component_interface = "0.0.0.0"
c2s_require_encryption = false
EOF

rm /etc/jitsi/videobridge/jvb.conf
cat >> /etc/jitsi/videobridge/jvb.conf << EOF
videobridge {
    http-servers {
        public {
            port = 9090
        }
        private {
            port = 8080
            tls-port = -1
            host = localhost
        }
    }
    websockets {
        enabled = true
        domain = "${HOSTNAME}:443"
        tls = true
    }
}
EOF

# zabbix monitoring
cat >> /etc/zabbix/zabbix_agentd.d/local.conf << EOF
UserParameter=jitsi.stats,curl -s "http://localhost:8080/colibri/stats"
EOF
systemctl restart zabbix-agent

apt-get -y autoremove

# restart services
systemctl restart prosody jicofo jitsi-videobridge2 nginx

cat >> /etc/jitsi/jwt_payload << EOF
{
  "aud": "jitsi",
  "iss": "${APP_ID}",
  "sub": "${APP_SECRET}",
  "room": "*"
}
EOF

cat >> /usr/local/bin/app-restart << EOF
#!/bin/bash
systemctl restart jicofo
systemctl restart jitsi-videobridge2
systemctl restart prosody
systemctl restart nginx
EOF
chmod +x /usr/local/bin/app-restart

# tail -f /var/log/prosody/prosody.log

# Get a jwt from: jwt.io
# https://${HOSTNAME}/Test42?jwt=longJWT

# reboot