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
  net-tools

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
DS_JWT_HEADER="AuthorizationJwt"

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
cp /etc/onlyoffice/documentserver/local.json /etc/onlyoffice/documentserver/local.json.saved

echo "*** Deactivate welcome page redirect"
sed -i \
    -e "s|rewrite ^/\$ \$the_scheme://\$the_host/welcome/ redirect;|rewrite ^/welcome(/)?\$ \$the_scheme://$the_host/ redirect;|" \
    /etc/onlyoffice/documentserver/nginx/includes/ds-docservice.conf

echo "*** Setup nginx https"
cp /etc/onlyoffice/documentserver/nginx/ds-ssl.conf.tmpl  /etc/nginx/conf.d/ds-ssl.conf
mkdir /etc/nginx/ssl

sed -i -e "s#{{SSL_CERTIFICATE_PATH}}#/etc/nginx/ssl/nginx.crt#" /etc/nginx/conf.d/ds-ssl.conf
sed -i -e "s#{{SSL_KEY_PATH}}#/etc/nginx/ssl/nginx.key#" /etc/nginx/conf.d/ds-ssl.conf

# fallback
(
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

# sed -i \
#   -e "s|access_log off;|access_log /var/log/onlyoffice/documentserver/nginx.access.log;|" \
#   /etc/onlyoffice/documentserver/nginx/includes/ds-common.conf
# tail /var/log/onlyoffice/documentserver/nginx.access.log
# vim /etc/onlyoffice/documentserver/local.json
# 
# 'onlyoffice' => array (
#   "jwt_secret" => "Jei4tiemee2peer3aeWeepah",
#   "jwt_header" => "AuthorizationJwt"
# ),
