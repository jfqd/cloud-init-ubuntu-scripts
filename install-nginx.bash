#!/bin/bash

apt -y -qq install nginx

cat  >> /etc/nginx/conf.d/status.conf << EOF
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
EOF
