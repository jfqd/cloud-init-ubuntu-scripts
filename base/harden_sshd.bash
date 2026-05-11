#!/usr/bin/bash

mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
cat > /etc/ssh/sshd_config << 'EOF'
# qutic-base sshd_config
Port 22
AddressFamily any
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
SyslogFacility AUTH
LogLevel INFO
LoginGraceTime 60
PermitRootLogin yes
StrictModes yes
MaxAuthTries 3
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
PermitEmptyPasswords no
KeepAlive yes
AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no
X11Forwarding no
X11UseLocalhost no
PrintMotd no
PermitUserEnvironment no
UseDNS no
VersionAddendum All your SSH belong to us
Subsystem       sftp    /usr/lib/openssh/sftp-server
EOF

sed -i \
    -e "s/PasswordAuthentication yes/PasswordAuthentication no/" \
    /etc/ssh/sshd_config.d/50-cloud-init.conf

systemctl restart ssh