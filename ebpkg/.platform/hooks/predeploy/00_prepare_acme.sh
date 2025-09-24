#!/usr/bin/env bash
set -e
mkdir -p /var/www/letsencrypt/.well-known/acme-challenge
echo ok > /var/www/letsencrypt/.well-known/acme-challenge/_health
chmod -R 755 /var/www/letsencrypt

