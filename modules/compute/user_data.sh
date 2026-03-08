#!/bin/bash

# =================================================================
# 1. UPDATE SISTEM & INSTALL SEMUA PAKET
# =================================================================
dnf update -y
# Install Nginx (Web/Proxy), Httpd (App), PHP, Git, dan CloudWatch Agent
dnf install -y nginx httpd git php php-mysqlnd amazon-cloudwatch-agent

# =================================================================
# 2. KONFIGURASI APACHE (APP TIER) - Port 8080
# =================================================================
# Mengubah port Apache dari 80 ke 8080 agar tidak bentrok dengan Nginx
sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

# Bersihkan folder web bawaan
rm -rf /var/www/html/*

# Clone aplikasi dari GitHub
git clone https://github.com/itsnall/eduflow-app.git /var/www/html/

# Konfigurasi koneksi Database ke RDS
# Variabel ini biasanya diisi otomatis oleh Terraform/Launch Template
sed -i "s/REPLACE_WITH_RDS_ENDPOINT/${rds_endpoint}/g" /var/www/html/config.php
sed -i "s/REPLACE_WITH_DB_USER/admin/g" /var/www/html/config.php
sed -i "s/REPLACE_WITH_DB_PASS/${rds_password}/g" /var/www/html/config.php

# Berikan izin akses folder kepada web server Apache
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

# =================================================================
# 3. KONFIGURASI REVERSE PROXY NGINX (WEB TIER) - Port 80
# =================================================================
INTERNAL_ALB_DNS="${internal_alb_dns_name}"

cat <<EOF > /etc/nginx/conf.d/proxy.conf
server {
    listen 80;
    server_name _;

    # Konfigurasi Frontend (Tampilan Utama)
    # Jika ingin diarahkan ke Apache lokal, ubah root atau gunakan proxy_pass
    location / {
        proxy_pass http://localhost:8080; # Mengarah ke Apache yang ada di port 8080
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # Reverse Proxy ke Internal ALB untuk API/Backend sesuai script original
    location /api/ {
        proxy_pass http://\$INTERNAL_ALB_DNS/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# File index sederhana untuk testing (Opsional, karena folder / sudah di-proxy ke Apache)
echo "<h1>Welcome to Web Tier (Frontend)</h1><p>Request ke /api akan diteruskan ke Internal ALB.</p>" > /usr/share/nginx/html/index.html

# =================================================================
# 4. KONFIGURASI CLOUDWATCH LOGS
# =================================================================
cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "eduflow-apache-access-logs",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "eduflow-apache-error-logs",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOT

# =================================================================
# 5. MENJALANKAN SEMUA SERVICE
# =================================================================
# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Start & Enable Apache dan Nginx
systemctl enable httpd nginx
systemctl restart httpd nginx