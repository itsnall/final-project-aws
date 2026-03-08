#!/bin/bash

# 1. Update sistem dan instal paket yang dibutuhkan
dnf update -y
dnf install -y httpd git php php-mysqlnd amazon-cloudwatch-agent

# 2. Mulai web server
systemctl start httpd
systemctl enable httpd

# 3. OTOMATISASI INSTALASI APLIKASI LMS (Poin 5)
# Bersihkan folder web bawaan
rm -rf /var/www/html/*

# Unduh (clone) kode aplikasi LMS Anda dari GitHub
# GANTI TAUTAN DI BAWAH dengan URL repositori GitHub aplikasi Anda
git clone https://github.com/itsnall/eduflow-app.git /var/www/html/
sed -i "s/REPLACE_WITH_RDS_ENDPOINT/${rds_endpoint}/g" /var/www/html/config.php
sed -i "s/REPLACE_WITH_DB_USER/admin/g" /var/www/html/config.php
sed -i "s/REPLACE_WITH_DB_PASS/${rds_password}/g" /var/www/html/config.php

# Berikan izin akses folder kepada web server Apache
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

# 4. KONFIGURASI CLOUDWATCH LOGS (Poin 4)
# Membuat file konfigurasi untuk mengirim Log Apache ke CloudWatch
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

# Mulai jalankan CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json