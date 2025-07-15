#!/usr/bin/env bash
set -euo pipefail

DOMAIN="girus.bingoprovider.com"
EMAIL="renatovieiradesouza1@gmail.com"

certbot --nginx -d "girus.bingoprovider.com" --non-interactive --agree-tos --email "$EMAIL" || true
