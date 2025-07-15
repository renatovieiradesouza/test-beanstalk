#!/usr/bin/env bash
DOMAIN=${LETSENCRYPT_DOMAIN}
EMAIL=${LETSENCRYPT_EMAIL}

# só roda uma vez (se não existir ainda)
if [ ! -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]; then
  certbot --nginx \
    --non-interactive \
    --redirect \
    --agree-tos \
    -m "$EMAIL" \
    -d "$DOMAIN"
fi

# cron de renovação diária às 3AM
cat <<EOF > /etc/cron.d/certbot-renew
0 3 * * * root certbot renew --post-hook "systemctl reload nginx"
EOF
