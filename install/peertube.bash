#!/usr/bin/bash

PEERTUBE_VERSION="8.1.8"
NODE_JS_VERSION="22.13.0"

export LC_ALL=en_US.utf8
export LANGUAGE=en_US.utf8
export LANG=en_US.utf8

/usr/bin/apt-get -y install curl unzip python3-dev python-is-python3 python3-pip \
  nginx apache2-utils ffmpeg openssl g++ make redis-server cron wget gpg htop \
  nfs-common ufw npm libvips-tools

MAIL_USER=$(/usr/sbin/mdata-get mail_auth_user)
DOMAIN=$(/usr/sbin/mdata-get peertube_domain)

echo "* Add postgresql repository to apt sources"
wget -O /usr/share/keyrings/postgresql.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgresql.list

echo "* Install requirements"
apt-get update
apt-get install -y postgresql postgresql-contrib

echo "* Setup postgresql"
sed -i 's/local   all             all                                     password/local   all             all                                     peer/' \
  /etc/postgresql/17/main/pg_hba.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" \
  /etc/postgresql/17/main/postgresql.conf

echo "* Setup node"
npm install -g inherits n
/usr/local/bin/n $NODE_JS_VERSION
node --version

echo "* Install pnpm"
sudo npm install -g pnpm

echo "* Start redis"
systemctl start redis  || true

echo "* Create peertube user and group"
addgroup peertube
adduser --disabled-password --system --quiet --home /var/www/peertube --shell /usr/bin/bash peertube
adduser peertube peertube
mkdir -p /var/www/peertube
chown -R peertube:peertube /var/www/peertube
chmod 0755 /var/www/peertube

echo "* Install peertube"
cd /var/www/peertube
mkdir config storage versions
chmod 750 config/
cd /var/www/peertube/versions
wget -q "https://github.com/Chocobozzz/PeerTube/releases/download/v${PEERTUBE_VERSION}/peertube-v${PEERTUBE_VERSION}.zip"
unzip -q peertube-v${PEERTUBE_VERSION}.zip
rm peertube-v${PEERTUBE_VERSION}.zip
cd /var/www/peertube
sudo -u peertube ln -nfs versions/peertube-v${PEERTUBE_VERSION} ./peertube-latest

( cd ./peertube-latest && sudo -H -u peertube pnpm run install-node-dependencies -- --production )

cp peertube-latest/config/production.yaml.example config/production.yaml
cp peertube-latest/config/default.yaml config/default.yaml

mkdir -p var/www/peertube/storage
mkdir -p var/www/peertube/storage-backup

cp /var/www/peertube/versions/peertube-v${PEERTUBE_VERSION}/support/nginx/peertube /etc/nginx/sites-available/peertube
ln -s /etc/nginx/sites-available/peertube /etc/nginx/sites-enabled/peertube

chown -R peertube:peertube /var/www/peertube

echo "* Configure peertube"
MAIL_UID=$(/usr/sbin/mdata-get mail_auth_user)
MAIL_PWD=$(/usr/sbin/mdata-get mail_auth_pass)
MAIL_HOST=$(/usr/sbin/mdata-get mail_smarthost)

DOMAIN=$(/usr/sbin/mdata-get peertube_domain)
ADMIN_EMAIL=$(/usr/sbin/mdata-get admin_email)
FROM_EMAIL=$(/usr/sbin/mdata-get from_email)
SECRET=$(openssl rand -hex 32)

sed -i \
    -e "s/hostname: 'example.com'/hostname: '${DOMAIN}'/" \
    -e "s/password: 'peertube'/password: '${DB_PWD}'/" \
    -e "s/peertube: ''/peertube: '${SECRET}'/" \
    -e "s/email: 'admin@example.com'/email: '${ADMIN_EMAIL}'/" \
    -e "s/from_address: 'admin@example.com'/from_address: '${FROM_EMAIL}'/" \
    -e "s/hostname: null/hostname: '${MAIL_HOST}'/" \
    -e "s/username: null/username: '${MAIL_UID}'/" \
    -e "s/password: null/password: '${MAIL_PWD}'/" \
    /var/www/peertube/config/production.yaml

echo "* Install systemd file"
cp current/support/systemd/peertube.service /etc/systemd/system/
sed -i \
    -e "s#/usr/bin/node#/usr/local/bin/node#" \
    /etc/systemd/system/peertube.service
systemctl daemon-reload

echo "* Setup nginx"
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes 5;
# worker_rlimit_nofile = (worker_connections * worker_processes) * 2
worker_rlimit_nofile 1024000;
pid /run/nginx.pid;

include /etc/nginx/modules-enabled/*.conf;

events {
  worker_connections 10240;
  # multi_accept on;
}

http {
  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;
  server_tokens off;
  
  # server_names_hash_bucket_size 64;
  # server_name_in_redirect off;
  
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  
  ##
  # SSL Settings
  ##
  
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;
  
  ##
  # Logging Settings
  ##
  
  log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" $upstream_response_time';
  
  access_log /var/log/nginx/access.log main;
  error_log /var/log/nginx/error.log;
  
  ##
  # Gzip Settings
  ##
  
  gzip on;
  
  # gzip_vary on;
  # gzip_proxied any;
  # gzip_comp_level 6;
  # gzip_buffers 16 8k;
  # gzip_http_version 1.1;
  # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
  
  ##
  # Virtual Host Configs
  ##
  server {
    listen 127.0.0.1;
    server_name localhost;
    location /nginx_status {
      stub_status on;
      access_log   off;
      allow 127.0.0.1;
      deny all;
    }
  }
  
  include /etc/nginx/conf.d/*.conf;
  include /etc/nginx/sites-enabled/*;
}
EOF

mkdir -p /etc/nginx/ssl/
chmod 0600 /etc/nginx/ssl/

cat > /usr/local/bin/ssl-selfsigned.sh << 'EOF'
#!/usr/bin/bash
# This script will generate a self signed ssl certificate for temporary
# usage and for development environment. It's moslty used if not ssl
# certificate is provided via mdata.

# Defaults
CN=$(hostname)
FILENAME='server'

# Help function
function help() {
        echo "${0} -d <DESTINATION> [-c common name] [-f filename]"
        exit 1
}

# Option parameters
if (( ${#} < 1 )); then help; fi

while getopts ":d:c:f:" opt; do
        case "${opt}" in
                d) DESTINATION=${OPTARG} ;;
                c) CN=${OPTARG} ;;
                f) FILENAME=${OPTARG} ;;
                *) help ;;
        esac
done

# Verify if folder exists
if [[ ! -d "$DESTINATION" ]]; then
        echo "Error: The ${DESTINATION} doesn't exists, please create!"
        exit 2
fi

# Generate key and csr via OpenSSL
openssl req -newkey rsa:2048 -keyout ${DESTINATION}/${FILENAME}.key \
            -out ${DESTINATION}/${FILENAME}.csr -nodes \
            -subj "/C=DE/L=Raindbow City/O=Aperture Science/OU=Please use valid ssl certificate/CN=${CN}"

# Generate self signed ssl certificate from csr via OpenSSL
openssl x509 -in ${DESTINATION}/${FILENAME}.csr -out ${DESTINATION}/${FILENAME}.crt -req \
             -signkey ${DESTINATION}/${FILENAME}.key -days 128

# Create one PEM file which contains certificate and key
cat ${DESTINATION}/${FILENAME}.crt ${DESTINATION}/${FILENAME}.key > ${DESTINATION}/${FILENAME}.pem
EOF
chmod +x /usr/local/bin/ssl-selfsigned.sh
/usr/local/bin/ssl-selfsigned.sh -d /etc/nginx/ssl -f nginx

sed -i \
  -e "s|/etc/letsencrypt/live/\${WEBSERVER_HOST}/fullchain.pem|/etc/nginx/ssl/nginx.crt|" \
  -e "s|/etc/letsencrypt/live/\${WEBSERVER_HOST}/privkey.pem|/etc/nginx/ssl/nginx.ke|" \
  -e "s/WEBSERVER_HOST/${DOMAIN}/g" \
  -e "s/\${PEERTUBE_HOST}/127.0.0.1:9000/g" \
  /etc/nginx/sites-enabled/peertube

echo "* Create bash-history"
cat > /root/.bash_history << EOF
systemctl edit --full peertube
systemctl daemon-reload
systemctl reset-failed peertube
systemctl stop peertube
systemctl start peertube
systemctl reload nginx
journalctl --since \$(date '+%Y-%m-%d')
journalctl -fu peertube
EOF

echo "* Confiugre postgresql user, db and extensions"
DB_PWD=$(openssl rand -hex 24)
sudo -u postgres psql -c "CREATE USER peertube;"
sudo -u postgres psql -c "ALTER USER peertube WITH PASSWORD '${DB_PWD}';"
sudo -u postgres createdb -O peertube -E UTF8 -T template0 peertube_prod
sudo -u postgres psql -c "CREATE EXTENSION pg_trgm;" peertube_prod
sudo -u postgres psql -c "CREATE EXTENSION unaccent;" peertube_prod

echo "* Setup postgresql backup"
mkdir -p /var/lib/postgresql/backups
chown postgres:postgres /var/lib/postgresql/backups
cat > /usr/local/bin/psql_backup << 'EOF'
#!/usr/bin/bash

NOW=`/bin/date "+%Y%m%d_%H%M%S"`

# backup all databases
/usr/bin/pg_dumpall | /bin/gzip > "/var/lib/postgresql/backups/${NOW}_peertube.pqsql.gz"
# only preserve the last 10 backups
/bin/ls -1dt /var/lib/postgresql/backups/*_peertube.pqsql.gz | /usr/bin/tail -n +11 | /usr/bin/xargs rm -rf

exit 0
EOF
chmod +x /usr/local/bin/psql_backup
cat > /var/spool/cron/crontabs/postgres << 'EOF'
MAILTO=root
0 1 * * * /usr/local/bin/psql_backup
0 2 1 * * /usr/bin/vacuumdb --all
EOF
chown postgres:crontab /var/spool/cron/crontabs/postgres
chmod 0600 /var/spool/cron/crontabs/postgres

if /usr/sbin/mdata-get vfstab 1>/dev/null 2>&1; then
  VFSTAB=$(mdata-get vfstab)
  # extend vfstab
  /usr/bin/cat >> /etc/fstab << EOF
$VFSTAB
EOF
  # mount directory
  # TODO: handle multiple lines
  MOUNTPOINT=$(/usr/bin/echo "$VFSTAB" | /usr/bin/awk '{print $2}')
  if [ -n "$MOUNTPOINT" ]; then
    systemctl daemon-reload
    /usr/bin/mkdir -p "$MOUNTPOINT"
    /usr/bin/mount "$MOUNTPOINT" || true
  fi
  
  systemctl start rpcbind.service
  systemctl enable rpcbind.service
fi

echo "* Start services"
systemctl start nginx
systemctl enable nginx

systemctl enable peertube || true
systemctl start peertube || true
