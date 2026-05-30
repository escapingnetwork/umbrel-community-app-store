#!/bin/sh
set -e

echo "Starting SimpleX Relay Dashboard with auto-restart..."

# Prepare mounted directories (run as root before starting the Go binary)
# This mirrors the fix we did for the chat gateway to avoid permission issues on volumes.
mkdir -p /etc/opt/simplex /var/opt/simplex \
         /etc/opt/simplex-xftp /var/opt/simplex-xftp /srv/xftp

# Drop ownership to root (the dashboard runs as root)
chown -R root:root /etc/opt/simplex /var/opt/simplex \
                   /etc/opt/simplex-xftp /var/opt/simplex-xftp /srv/xftp 2>/dev/null || true

while true; do
    /usr/local/bin/dashboard || true
    echo "Dashboard exited. Restarting in 5 seconds..."
    sleep 5
done
