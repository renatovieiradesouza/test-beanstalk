#!/usr/bin/env bash
set -e

# instalar certbot e plugin nginx direto do repositório AL2023
sudo dnf install -y certbot python3-certbot-nginx

yum clean metadata

# 2) Instala o Certbot e o plugin para nginx
yum install -y certbot python3-certbot-nginx || true

# 3) (Opcional) limpa metadados
yum clean all

#!/usr/bin/env bash
sudo certbot -n -d girus.bingoprovider.com --nginx --agree-tos --email renatovieiradesouza1@gmail.com

# Create a cronjob
