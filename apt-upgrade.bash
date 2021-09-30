#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

apt-get -y update
yes no | apt-get -y -qq upgrade
yes no | apt-get -y -qq dist-upgrade

# apt-get -y -qq dist-upgrade

cat >> /usr/local/bin/uptodate << EOF
#!/bin/bash

/usr/bin/apt-get update
/usr/bin/apt-get -y upgrade
/usr/bin/apt-get -y dist-upgrade
/usr/bin/apt-get -y autoremove

EOF
chmod +x /usr/local/bin/uptodate
