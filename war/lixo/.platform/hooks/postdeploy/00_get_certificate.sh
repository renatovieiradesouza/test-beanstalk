#!/usr/bin/env bash
set -e

DOMAIN="girus.pipastudios.com"
EMAIL="admin@pipastudios.com"

echo "Issuing/renewing certificate for $DOMAIN (webroot)"

# Ensure webroot exists
mkdir -p /var/www/letsencrypt

# Obtain/renew certificate using webroot challenge (Nginx must be serving /.well-known/acme-challenge/)
certbot certonly \
  --webroot -w /var/www/letsencrypt \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  -d "$DOMAIN" || true

# Reload nginx to pick up new certs
systemctl reload nginx || service nginx reload || true

echo "Certificate process completed for $DOMAIN"


