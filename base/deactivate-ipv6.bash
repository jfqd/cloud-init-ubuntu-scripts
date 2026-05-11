#!/usr/bin/bash

cat >> /etc/sysctl.conf << EOF

net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
EOF
sysctl -p

cat >> /etc/rc.local << EOF
#!/usr/bin/bash
# /etc/rc.local

/etc/sysctl.d
/etc/init.d/procps restart

exit 0
EOF
chmod 0755 /etc/rc.local
