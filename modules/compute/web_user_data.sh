#!/define/bash

# Update sistem dan install Nginx
dnf update -y
dnf install -y nginx

# Start dan enable Nginx
systemctl start nginx
systemctl enable nginx

# Variabel DNS Internal ALB 
INTERNAL_ALB_DNS="${internal_alb_dns_name}"

#konfigurasi Reverse Proxy Nginx
cat <<EOF > /etc/nginx/conf.d/proxy.conf
server {
    listen 80;
    server_name _;

    # Konfigurasi Frontend
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
    }

    # Reverse Proxy ke Internal ALB untuk API/Backend
    # semua request yang dimulai dengan /api akan dilempar ke App Tier
    location /api/ {
        proxy_pass http://\$INTERNAL_ALB_DNS/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF


# rm /etc/nginx/conf.d/default.conf

# file index sederhana untuk testing Web Tier
echo "<h1>Welcome to Web Tier (Frontend)</h1><p>Request ke /api akan diteruskan ke Internal ALB.</p>" > /usr/share/nginx/html/index.html

# Restart Nginx
systemctl restart nginx