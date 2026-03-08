#!/bin/bash
dnf update -y
dnf install -y httpd git php php-mysqlnd amazon-cloudwatch-agent

systemctl start httpd
systemctl enable httpd

# Hapus bawaan dan Clone dari GitHub
rm -rf /var/www/html/*
git clone https://github.com/itsnall/eduflow-app.git /var/www/html/

# Injeksi RDS
sed -i "s/REPLACE_WITH_RDS_ENDPOINT/${rds_endpoint}/g" /var/www/html/config.php
sed -i "s/REPLACE_WITH_DB_USER/admin/g" /var/www/html/config.php
sed -i "s/REPLACE_WITH_DB_PASS/${rds_password}/g" /var/www/html/config.php

chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/