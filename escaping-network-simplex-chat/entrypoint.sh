#!/bin/bash
set -euo pipefail

# SimpleX Chat Daemon + Gateway Proxy + Web UI for Umbrel
# Designed specifically as a gateway for Hermes Agent (Nous Research)

DATA_DIR="${SIMPLEX_DATA_DIR:-/data}"
WS_PORT=5225
WEB_PORT=8080

echo "=================================================="
echo "  SimpleX Chat Daemon (Umbrel Gateway)"
echo "  Data directory: ${DATA_DIR}"
echo "=================================================="

mkdir -p "${DATA_DIR}"
cd "${DATA_DIR}"

# Auto-create bot profile on first run (only if DB doesn't exist yet)
if [ ! -f "${DATA_DIR}/simplex_v1_chat.db" ]; then
    echo "[entrypoint] No existing database found. Creating bot profile..."
    /usr/local/bin/simplex-chat \
        -d "${DATA_DIR}" \
        --create-bot-display-name "Hermes Gateway" \
        --create-bot-allow-files || true
    sleep 3
fi

# Start sidecar services in background
echo "[entrypoint] Starting socat proxy on 0.0.0.0:${WS_PORT}..."
socat TCP-LISTEN:${WS_PORT},fork,reuseaddr,bind=0.0.0.0 \
      TCP:127.0.0.1:${WS_PORT} &

echo "[entrypoint] Starting web dashboard on 0.0.0.0:${WEB_PORT}..."
cd /app/web
python3 -m http.server "${WEB_PORT}" &

# Run simplex-chat in a resilient loop.
# The prebuilt binary sometimes exits; this keeps the container alive
# and makes debugging much easier.
echo "[entrypoint] Starting simplex-chat daemon (with auto-restart)..."
while true; do
    /usr/local/bin/simplex-chat \
        -d "${DATA_DIR}" \
        -p ${WS_PORT} || true

    echo "[entrypoint] simplex-chat exited. Restarting in 5 seconds..."
    sleep 5
done
