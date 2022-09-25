#!/bin/bash

echo "*** Install requirements"
apt-get install -y \
  dnsutils \
  dirmngr \
  gnupg \
  expect \
  rabbitmq-server \
  redis-server \
  postgresql \
  debconf-utils \
  net-tools \
  jq

echo "*** Setup database"
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5
echo "deb https://download.onlyoffice.com/repo/debian squeeze main" | tee /etc/apt/sources.list.d/onlyoffice.list
apt-get update

echo "*** Preconfigure documentserver"
DS_PORT=80
DS_DB_HOST=localhost
DS_DB_NAME=onlyoffice
DS_DB_USER=onlyoffice
DS_DB_PWD=$(/usr/sbin/mdata-get psql_pwd)
DS_JWT_ENABLED=false
DS_JWT_SECRET="${DS_DB_PWD}"
DS_JWT_HEADER="Authorization"

echo onlyoffice-documentserver onlyoffice/ds-port select ${DS_PORT} | debconf-set-selections
echo onlyoffice-documentserver onlyoffice/db-pwd password ${DS_DB_PWD} | debconf-set-selections
echo onlyoffice-documentserver onlyoffice/db-host string ${DS_DB_HOST} | debconf-set-selections
echo onlyoffice-documentserver onlyoffice/db-user string $DS_DB_USER | debconf-set-selections
echo onlyoffice-documentserver onlyoffice/db-name string $DS_DB_NAME | debconf-set-selections
echo onlyoffice-documentserver onlyoffice/jwt-enabled select ${DS_JWT_ENABLED} | debconf-set-selections
echo onlyoffice-documentserver onlyoffice/jwt-secret select ${DS_JWT_SECRET} | debconf-set-selections
echo onlyoffice-documentserver onlyoffice/jwt-header select ${DS_JWT_HEADER} | debconf-set-selections
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections

echo "*** Setup database"
sudo -i -u postgres psql -c "CREATE DATABASE onlyoffice;"
sudo -i -u postgres psql -c "CREATE USER onlyoffice WITH password '${DS_DB_PWD}';"
sudo -i -u postgres psql -c "GRANT ALL privileges ON DATABASE onlyoffice TO onlyoffice;"

echo "*** Install documentserver"
apt-get -yq install onlyoffice-documentserver

echo "*** Allow nextcloud to access onlyoffice"
sed -i 
   -e "s|\"inbox\": false|\"inbox\": true|" \
   -e "s|\"outbox\": false|\"outbox\": true|" \
   -e "s|\"browser\": false|\"browser\": true|" \
   /etc/onlyoffice/documentserver/local.json

cp /etc/onlyoffice/documentserver/local.json /etc/onlyoffice/documentserver/local.json.saved

echo "*** Deactivate welcome and example page"
sed -i \
    -e "s|rewrite ^/\$ \$the_scheme://\$the_host/welcome/ redirect;|rewrite ^/(welcome|example)(/)?\$ \$the_scheme://\$the_host/ redirect;|" \
    /etc/onlyoffice/documentserver/nginx/includes/ds-docservice.conf

echo "*** Setup nginx https"
cp /etc/onlyoffice/documentserver/nginx/ds-ssl.conf.tmpl /etc/nginx/conf.d/ds-ssl.conf

FS_SECRET=$(jq ".storage.fs.secretString" /etc/onlyoffice/documentserver/local.json | sed -s "s|\"||g")
sed -i \
    -e "s|verysecretstring|${FS_SECRET}|g" \
    /etc/nginx/conf.d/ds-ssl.conf

# create self sign cert, that nginx will start
(
  mkdir /etc/nginx/ssl
  cd /etc/nginx/ssl
  CN=$(hostname)
  openssl req -newkey rsa:2048 -keyout nginx.key \
              -out nginx.csr -nodes \
              -subj "/C=DE/L=Raindbow City/O=Aperture Science/OU=Please use valid ssl certificate/CN=${CN}"

  openssl x509 -in nginx.csr -out nginx.crt -req \
               -signkey nginx.key -days 3650

  cat nginx.crt nginx.key > nginx.pem
  chmod 0600 nginx.key
  chmod 0600 nginx.pem
)

sed -i -e "s#{{SSL_CERTIFICATE_PATH}}#/etc/nginx/ssl/nginx.crt#" /etc/nginx/conf.d/ds-ssl.conf
sed -i -e "s#{{SSL_KEY_PATH}}#/etc/nginx/ssl/nginx.key#" /etc/nginx/conf.d/ds-ssl.conf

mv /etc/nginx/conf.d/ds.conf /etc/nginx/conf.d/ds.conf.bak
systemctl restart nginx

echo "*** Restart documentserver"
supervisorctl restart all
supervisorctl stop ds:example

cat > /usr/local/bin/uptodate << EOF
#!/bin/bash

apt-get update
apt-get -y upgrade

cp /etc/onlyoffice/documentserver/local.json.saved /etc/onlyoffice/documentserver/local.json
supervisorctl restart all; supervisorctl stop ds:example

systemctl restart nginx
systemctl restart rabbitmq-server
systemctl restart redis-server

# tail -f /var/log/onlyoffice/documentserver/*.log
EOF

# echo "*** Activate access-log"
# sed -i \
#   -e "s|access_log off;|access_log /var/log/onlyoffice/documentserver/nginx.access.log;|" \
#   /etc/onlyoffice/documentserver/nginx/includes/ds-common.conf
