#!/bin/bash
dnf update -y
dnf install -y nginx

# Ambil URL Internal ALB dari Terraform
INTERNAL_ALB_DNS="${internal_alb_dns_name}"

# Timpa seluruh konfigurasi Nginx agar bersih dan tidak bentrok
cat <<EOF > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    sendfile            on;
    keepalive_timeout   65;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;

        # Lempar SEMUA traffic ke App Tier (Internal ALB)
        location / {
            proxy_pass http://$INTERNAL_ALB_DNS;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
}
EOF

# Jalankan Nginx
systemctl enable nginx
systemctl restart nginx