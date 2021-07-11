#!/bin/bash

apt-get -y update
yes no | apt-get -y -qq upgrade

# apt-get -y -qq dist-upgrade

cat >> /usr/local/bin/uptodate << EOF
#!/bin/bash

/usr/bin/apt-get update
/usr/bin/apt-get -y upgrade
/usr/bin/apt-get -y autoremove

EOF
chmod +x /usr/local/bin/uptodate
