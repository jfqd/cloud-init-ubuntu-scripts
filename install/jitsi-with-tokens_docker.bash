#!/usr/bin/bash

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

apt-get -y remove docker docker-engine docker.io
apt-get -y install docker.io docker-compose
git clone https://github.com/jitsi/docker-jitsi-meet.git
cd docker-jitsi-meet
cp env.example .env
./gen-passwords.sh
mkdir -p ~/.jitsi-meet-cfg/{web/letsencrypt,transcripts,prosody/config,prosody/prosody-plugins-custom,jicofo,jvb,jigasi,jibri}

sed -i \
    -e "s|#PUBLIC_URL=https://meet.example.com:8443|PUBLIC_URL=https://${HOSTNAME}|" \
    -e "s|#ENABLE_PREJOIN_PAGE=0|ENABLE_PREJOIN_PAGE=1|" \
    -e "s|#ENABLE_WELCOME_PAGE=1|ENABLE_WELCOME_PAGE=0|" \
    -e "s|#ENABLE_CLOSE_PAGE=0|ENABLE_CLOSE_PAGE=0|" \
    -e "s|#DISABLE_AUDIO_LEVELS=0|DISABLE_AUDIO_LEVELS=1|" \
    -e "s|#ENABLE_LETSENCRYPT=1|ENABLE_LETSENCRYPT=1|" \
    -e "s|#LETSENCRYPT_DOMAIN=meet.example.com|LETSENCRYPT_DOMAIN=${HOSTNAME}|" \
    -e "s|#LETSENCRYPT_EMAIL=alice@atlanta.net|LETSENCRYPT_EMAIL=${EMAIL}|" \
    -e "s|#ENABLE_AUTH=1|ENABLE_AUTH=1|" \
    -e "s|#ENABLE_GUESTS=1|ENABLE_GUESTS=1|" \
    -e "s|#AUTH_TYPE=internal|AUTH_TYPE=jwt|" \
    -e "s|#JWT_APP_ID=my_jitsi_app_id|JWT_APP_ID=${APP_ID}|" \
    -e "s|#JWT_APP_SECRET=my_jitsi_app_secret|JWT_APP_SECRET=${APP_SECRET}|" \
    .env

cat >> .env << EOF

JWT_AUTH_TYPE=token
JWT_TOKEN_AUTH_MODULE=token_verification
EOF

# docker-compose ps
# docker-compose up -d
# docker-compose logs -f
# 
# docker-compose exec prosody /bin/bash
