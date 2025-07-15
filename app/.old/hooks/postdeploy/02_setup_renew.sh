#!/usr/bin/env bash
set -e

cat << 'CRONJOB' > /etc/cron.d/renew_certbot
# Renew Let's Encrypt certs on dia 1 e 15, às 01:00
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
0 1,15 * * * root certbot renew --no-self-upgrade >> /var/log/letsencrypt/renew.log 2>&1
CRONJOB

chmod 644 /etc/cron.d/renew_certbot
# Reinicia/cria o serviço cron pra ler o novo arquivo
if command -v systemctl &> /dev/null; then
  systemctl restart crond
else
  service crond restart
fi
