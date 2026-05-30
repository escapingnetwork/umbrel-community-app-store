#!/bin/sh

# Exports connection details so other Umbrel apps (especially Hermes Agent)
# can easily discover and use this SimpleX Gateway.

# The service name in docker-compose is "app".
# Umbrel injects APP_SIMPLEX_CHAT_IP (the internal Docker IP of the container).
# We also provide the Docker Compose service DNS name as a convenience.

export APP_SIMPLEX_CHAT_WS_HOST="${APP_SIMPLEX_CHAT_IP:-simplex-chat_app_1}"
export APP_SIMPLEX_CHAT_WS_PORT="5225"

# Full WebSocket URL ready to use
export APP_SIMPLEX_CHAT_WS_URL="ws://${APP_SIMPLEX_CHAT_WS_HOST}:${APP_SIMPLEX_CHAT_WS_PORT}"

# Human friendly name for logs / UIs
export APP_SIMPLEX_CHAT_NAME="SimpleX Gateway"

echo "SimpleX Gateway exports loaded:"
echo "  APP_SIMPLEX_CHAT_WS_URL=${APP_SIMPLEX_CHAT_WS_URL}"
