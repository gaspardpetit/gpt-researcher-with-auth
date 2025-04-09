#!/bin/bash

# Ensure Nginx auth directory exists
mkdir -p /etc/nginx/auth

# Check if BASIC_AUTH_USER and BASIC_AUTH_PASS are set
if [ -z "$BASIC_AUTH_USER" ] || [ -z "$BASIC_AUTH_PASS" ]; then
    echo "Error: BASIC_AUTH_USER and BASIC_AUTH_PASS must be set"
    exit 1
fi

# Generate the htpasswd file securely using bcrypt
htpasswd -cbB /etc/nginx/auth/.htpasswd "$BASIC_AUTH_USER" "$BASIC_AUTH_PASS"

# Start Uvicorn in the background
uvicorn main:app --host 0.0.0.0 --port 8000 &

# Start Nginx in the foreground
exec nginx -g "daemon off;"

