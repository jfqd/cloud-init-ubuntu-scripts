#!/usr/bin/bash

PATH=/usr/sbin:/usr/bin

echo "*** Install requirements"
apt-get install -y git make protobuf-compiler golang-go janus nginx

# TODO: Certbot && Coturn &&UFW!

curl -fsSL https://binaries.nats.dev/nats-io/nats-server/v2@v2.11.6 | sh
cat > /etc/systemd/system/nats.service << 'EOF'
[Unit]
Description=NATS Server
After=network-online.target ntp.service

# If you use a dedicated filesystem for JetStream data, then you might use something like:
# ConditionPathIsMountPoint=/srv/jetstream
# See also Service.ReadWritePaths

[Service]
Type=simple
EnvironmentFile=-/etc/default/nats-server
ExecStart=/usr/sbin/nats-server -c /etc/nats-server.conf
ExecReload=/bin/kill -s HUP $MAINPID

# The nats-server uses SIGUSR2 to trigger Lame Duck Mode (LDM) shutdown
# https://docs.nats.io/running-a-nats-service/nats_admin/lame_duck_mode
ExecStop=/bin/kill -s SIGUSR2  $MAINPID

User=nats
Group=nats

Restart=on-failure
RestartSec=5

# This should be `lame_duck_duration` + some buffer to finish the shutdown.
# By default, `lame_duck_duration` is 2 mins.
TimeoutStopSec=150

# Capacity Limits
# JetStream requires 2 FDs open per stream.
LimitNOFILE=800000
# Environment=GOMEMLIMIT=12GiB
# You might find it better to set GOMEMLIMIT via /etc/default/nats-server,
# so that you can change limits without needing a systemd daemon-reload.

# Hardening
CapabilityBoundingSet=
LockPersonality=true
MemoryDenyWriteExecute=true
NoNewPrivileges=true
PrivateDevices=true
PrivateTmp=true
PrivateUsers=true
ProcSubset=pid
ProtectClock=true
ProtectControlGroups=true
ProtectHome=true
ProtectHostname=true
ProtectKernelLogs=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectSystem=strict
ReadOnlyPaths=
RestrictAddressFamilies=AF_INET AF_INET6
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
SystemCallFilter=@system-service ~@privileged ~@resources
UMask=0077

# Consider locking down all areas of /etc which hold machine identity keys, etc
InaccessiblePaths=/etc/ssh

# If you have systemd >= 247
ProtectProc=invisible

# If you have systemd >= 248
PrivateIPC=true

# Optional: writable directory for JetStream.
# See also: Unit.ConditionPathIsMountPoint
ReadWritePaths=/var/lib/nats

# Optional: resource control.
# Replace weights by values that make sense for your situation.
# For a list of all options see:
# https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html
#CPUAccounting=true
#CPUWeight=100 # of 10000
#IOAccounting=true
#IOWeight=100 # of 10000
#MemoryAccounting=true
#MemoryMax=1GB
#IPAccounting=true

[Install]
WantedBy=multi-user.target
# If you install this service as nats-server.service and want 'nats'
# to work as an alias, then uncomment this next line:
#Alias=nats.service
EOF

groupadd signaling
useradd --system --gid signaling --shell /usr/sbin/nologin --comment "Standalone signaling server for Nextcloud Talk." signaling

mkdir -p cd /usr/local/src
cd /usr/local/src
git clone https://github.com/strukturag/nextcloud-spreed-signaling.git
cd nextcloud-spreed-signaling
make build
cp server.conf.in server.conf

# TODO sed config

mkdir -p /etc/signaling
mv server.conf /etc/signaling/server.conf
chmod 600 /etc/signaling/server.conf
chown signaling: /etc/signaling/server.conf

cat > /etc/systemd/system/signaling.service << 'EOF'
[Unit]
Description=Nextcloud Talk signaling server

[Service]
ExecStart=/usr/local/src/nextcloud-spreed-signaling/bin/signaling --config /etc/signaling/server.conf
User=signaling
Group=signaling
Restart=on-failure

# Makes sure that /etc/signaling is owned by this service
ConfigurationDirectory=signaling

# Hardening - see systemd.exec(5)
CapabilityBoundingSet=
ExecPaths=/etc/nextcloud-spreed-signaling/bin/signaling /usr/lib
LockPersonality=yes
MemoryDenyWriteExecute=yes
NoExecPaths=/
NoNewPrivileges=yes
PrivateDevices=yes
PrivateTmp=yes
PrivateUsers=yes
ProcSubset=pid
ProtectClock=yes
ProtectControlGroups=yes
ProtectHome=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectProc=invisible
ProtectSystem=strict
RemoveIPC=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~ @privileged

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable signaling.service
systemctl start signaling.service

cat > << 'EOF'
upstream signaling {
    server 127.0.0.1:8080;
}

server {
    listen 443 ssl http2;
    server_name myserver.domain.invalid;

    # ... other existing configuration ...

    location /standalone-signaling/ {
        proxy_pass http://signaling/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /standalone-signaling/spreed {
        proxy_pass http://signaling/spreed;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF