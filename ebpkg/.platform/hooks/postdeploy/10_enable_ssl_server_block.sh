#!/usr/bin/env bash
set -e

DOMAIN="girus.pipastudios.com"
SSL_DIR="/etc/letsencrypt/live/$DOMAIN"
CONF="/etc/nginx/conf.d/ssl_app.conf"

# Always start from a clean state
rm -f "$CONF" || true

# Write HTTP server for ACME and app proxy
cat > /etc/nginx/conf.d/app_http.conf <<'EOF'
server {
  listen 80;
  server_name _;

  location ^~ /.well-known/acme-challenge/ {
    root /var/www/letsencrypt;
    default_type text/plain;
    add_header Cache-Control "no-store";
  }

  location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
EOF

# If LE certs exist, add HTTPS server and redirect HTTP
if [ -f "$SSL_DIR/fullchain.pem" ] && [ -f "$SSL_DIR/privkey.pem" ]; then
  cat > "$CONF" <<EOF
server {
  listen 443 ssl;
  server_name $DOMAIN;
  ssl_certificate     $SSL_DIR/fullchain.pem;
  ssl_certificate_key $SSL_DIR/privkey.pem;
  location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
  }
}
server {
  listen 80;
  server_name $DOMAIN;
  location ^~ /.well-known/acme-challenge/ { root /var/www/letsencrypt; default_type text/plain; add_header Cache-Control "no-store"; }
  location / { return 301 https://\$host\$request_uri; }
}
EOF
fi

systemctl reload nginx || service nginx reload || true
