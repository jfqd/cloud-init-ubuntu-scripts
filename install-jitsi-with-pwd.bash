#!/bin/bash

HOSTNAME=$(/usr/sbin/mdata-get sdc:hostname)

sed -i "s/#DefaultLimitNOFILE=/DefaultLimitNOFILE=65000/" /etc/systemd/system.conf
sed -i "s/#DefaultLimitNPROC=/DefaultLimitNPROC=65000/" /etc/systemd/system.conf
sed -i "s/#DefaultTasksMax=/DefaultTasksMax=65000/" /etc/systemd/system.conf

curl -Ls https://download.jitsi.org/jitsi-key.gpg.key | apt-key add -
echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list
apt-get -y update

# https://github.com/jitsi/jitsi-meet/issues/5759
echo "jitsi-videobridge jitsi-videobridge/jvb-hostname string ${HOSTNAME}" | debconf-set-selections
echo "jitsi-meet-web-config jitsi-meet/cert-choice select 'Generate a new self-signed certificate (You will later get a chance to obtain a Let's encrypt certificate)'" | debconf-set-selections
apt-get --option=Dpkg::Options::=--force-confold --option=Dpkg::options::=--force-unsafe-io --assume-yes --quiet install jitsi-meet

sed -i 's|read EMAIL|EMAIL=$(/usr/sbin/mdata-get mail_adminaddr)|' /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
/usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

cp /etc/prosody/conf.avail/jm-${HOSTNAME}.cfg.lua /etc/prosody/conf.avail/jm-${HOSTNAME}.cfg.lua.orig

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

# TODO: activate monitoring

# restart services
service jicofo restart
service jitsi-videobridge2 restart
service prosody restart
service nginx restart
