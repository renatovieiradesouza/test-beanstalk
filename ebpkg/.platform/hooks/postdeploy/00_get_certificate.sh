#!/usr/bin/env bash
set -e

DOMAIN="girus.pipastudios.com"
EMAIL="admin@pipastudios.com"

echo "Issuing/renewing certificate for $DOMAIN (standalone)"

# Stop nginx to free port 80 for standalone server
systemctl stop nginx || service nginx stop || true

certbot certonly \
  --standalone \
  --staging \
  --preferred-challenges http \
  --http-01-port 80 \
  --non-interactive \
  --agree-tos \
  --email "$EMAIL" \
  -d "$DOMAIN" || true

# Start nginx again
systemctl start nginx || service nginx start || true

echo "Certificate process completed for $DOMAIN"


