#!/usr/bin/bash

HOSTNAME=$(/usr/sbin/mdata-get sdc:hostname)

sed -i "s/#DefaultLimitNOFILE=/DefaultLimitNOFILE=65000/" /etc/systemd/system.conf
sed -i "s/#DefaultLimitNPROC=/DefaultLimitNPROC=65000/" /etc/systemd/system.conf
sed -i "s/#DefaultTasksMax=/DefaultTasksMax=65000/" /etc/systemd/system.conf

# echo deb http://packages.prosody.im/debian $(lsb_release -sc) main | tee -a /etc/apt/sources.list
# wget https://prosody.im/files/prosody-debian-packages.key -O- | apt-key add -
# apt-get update
# apt-get -y -qq install prosody

curl -Ls https://download.jitsi.org/jitsi-key.gpg.key | apt-key add -
echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list
apt-get update

# https://github.com/jitsi/jitsi-meet/issues/5759
echo "jitsi-videobridge jitsi-videobridge/jvb-hostname string ${HOSTNAME}" | debconf-set-selections
echo "jitsi-meet-web-config jitsi-meet/cert-choice select 'Generate a new self-signed certificate (You will later get a chance to obtain a Let's encrypt certificate)'" | debconf-set-selections
apt-get --option=Dpkg::Options::=--force-confold --option=Dpkg::options::=--force-unsafe-io --assume-yes --quiet install jitsi-meet

echo "Include \"conf.d/*.cfg.lua\"" >> /etc/prosody/prosody.cfg.lua

sed -i 's|read EMAIL|EMAIL=$(/usr/sbin/mdata-get mail_adminaddr)|' /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
/usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

cp /etc/prosody/conf.avail/${HOSTNAME}.cfg.lua /etc/prosody/conf.avail/${HOSTNAME}.cfg.lua.orig

sed -i -e "s#authentication = \"anonymous\"#authentication = \"internal_plain\"#" /etc/prosody/conf.avail/${HOSTNAME}.cfg.lua

cat >> /etc/prosody/conf.avail/${HOSTNAME}.cfg.lua << EOF

VirtualHost "guest.${HOSTNAME}"
    authentication = "anonymous"
    c2s_require_encryption = false
EOF

sed -i -e "s#// anonymousdomain: 'guest.example.com',#anonymousdomain: 'guest.${HOSTNAME}',#" /etc/jitsi/meet/${HOSTNAME}-config.js

echo "org.jitsi.jicofo.auth.URL=XMPP:${HOSTNAME}" >> /etc/jitsi/jicofo/sip-communicator.properties

# special config
sed -i \
    -e "s#// requireDisplayName: true,#requireDisplayName: true,#" \
    -e "s#enableWelcomePage: true,#enableWelcomePage: false,#" \
    -e "s#// doNotStoreRoom: true,#doNotStoreRoom: true,#" \
    -e "s#// defaultLanguage: 'en',#defaultLanguage: 'de',#" \
    -e "#// prejoinPageEnabled: false,#prejoinPageEnabled: true,#" \
    -e "#// disableThirdPartyRequests: false,#disableThirdPartyRequests: true,#" \
    -e "#// enableLayerSuspension: false,#enableLayerSuspension: true,#" \
    -e "#// disableAudioLevels: false,#disableAudioLevels: true,#" \
    /etc/jitsi/meet/${HOSTNAME}-config.js

# activate private rest endpoint
if [[ $(grep JVB_OPTS /etc/jitsi/videobridge/config | wc -l) -gt 0 ]]; then
  sed -i -e "s|JVB_OPTS=\"--apis=.\"|JVB_OPTS=\"--apis=rest\"|" /etc/jitsi/videobridge/config
else
  cat >> /etc/jitsi/videobridge/config << EOF

JVB_OPTS="--apis=rest"  
EOF
fi
  
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

cat >> /usr/local/bin/register << 'EOF'
#!/usr/bin/bash

prosodyctl register $1 $(hostname) $2
EOF
chmod +x /usr/local/bin/register

PROSODY_USR=$(/usr/sbin/mdata-get prosody_usr)
PROSODY_PWD=$(/usr/sbin/mdata-get prosody_pwd)
if [[ "${PROSODY_USR}" && "${PROSODY_PWD}" ]]; then
  /usr/local/bin/register "${PROSODY_USR}" "${PROSODY_PWD}"
fi

# restart services
systemctl restart prosody
systemctl restart jicofo
systemctl restart jitsi-videobridge2
systemctl restart nginx
