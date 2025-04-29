#!/bin/bash

CERT_DIR="/etc/ssl/dovecot"
CERT_FILE="$CERT_DIR/dovecot.pem"
KEY_FILE="$CERT_DIR/dovecot.key"

# Create directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Generate new self-signed cert (valid for 366 days)
openssl req -new -x509 -days 366 -nodes \
  -out "$CERT_FILE" \
  -keyout "$KEY_FILE" \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=mail.yourdomain.com"

# Restart Dovecot to load new cert
service dovecot restart
