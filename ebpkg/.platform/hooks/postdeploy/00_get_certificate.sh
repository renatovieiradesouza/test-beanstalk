#!/usr/bin/env bash
set -e

DOMAIN="girus.pipastudios.com"
EMAIL="admin@pipastudios.com"

echo "Issuing/renewing certificate for $DOMAIN (webroot staging)"
mkdir -p /var/www/letsencrypt/.well-known/acme-challenge

certbot certonly \
  --webroot -w /var/www/letsencrypt \
  --staging \
  --preferred-challenges http \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  -d "$DOMAIN" || true

echo "Certificate process completed for $DOMAIN"

