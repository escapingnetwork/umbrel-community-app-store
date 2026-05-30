#!/bin/sh
set -e

echo "Starting SimpleX Relay Dashboard with auto-restart..."

while true; do
    /usr/local/bin/dashboard || true
    echo "Dashboard exited. Restarting in 5 seconds..."
    sleep 5
done
