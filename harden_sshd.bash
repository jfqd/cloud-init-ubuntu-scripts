!/usr/bin/bash

sed -i \
    -e "s/PermitRootLogin yes/PermitRootLogin no/" \
    -e "s/PasswordAuthentication yes/PasswordAuthentication no/" \
    -e "s/UsePAM yes/UsePAM no/" \
    -e "s/X11Forwarding yes/X11Forwarding no/" \
    /etc/ssh/sshd_config

cat >> /etc/ssh/sshd_config << EOF

ChallengeResponseAuthentication no
EOF

sed -i \
    -e "s/PasswordAuthentication yes/PasswordAuthentication no/" \
    /etc/ssh/sshd_config.d/50-cloud-init.conf

systemctl restart ssh