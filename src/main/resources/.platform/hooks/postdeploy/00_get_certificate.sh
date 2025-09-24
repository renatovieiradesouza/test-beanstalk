#!/usr/bin/env bash
set -e

# Domain for SSL certificate
DOMAIN="girus.pipastudios.com"
EMAIL="admin@pipastudios.com"

# Check if certificate already exists

echo "Getting SSL certificate for domain: $DOMAIN"

    # Stop apache temporarily
    service httpd stop
    
    # Get certificate
    certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL -d $DOMAIN
    
    # Start apache
    service httpd start

echo "SSL certificate obtained successfully for $DOMAIN"