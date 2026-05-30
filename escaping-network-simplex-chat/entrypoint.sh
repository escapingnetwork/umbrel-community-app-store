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

# Auto-create bot profile on first run
if [ ! -f "${DATA_DIR}/simplex_v1_chat.db" ]; then
    echo "[entrypoint] No existing database found. Creating bot profile..."
    /usr/local/bin/simplex-chat \
        -d "${DATA_DIR}" \
        --create-bot-display-name "Hermes Gateway" \
        --create-bot-allow-files \
        +RTS -M1G -RTS || true
    sleep 2
fi

# Start sidecar services in background
echo "[entrypoint] Starting socat proxy on 0.0.0.0:${WS_PORT}..."
socat TCP-LISTEN:${WS_PORT},fork,reuseaddr,bind=0.0.0.0 \
      TCP:127.0.0.1:${WS_PORT} &

echo "[entrypoint] Starting web dashboard on 0.0.0.0:${WEB_PORT}..."
cd /app/web
python3 -m http.server "${WEB_PORT}" &

# Run the main simplex-chat daemon in the foreground.
# This is what keeps the container alive.
echo "[entrypoint] Starting simplex-chat daemon..."
exec /usr/local/bin/simplex-chat \
    -d "${DATA_DIR}" \
    -p ${WS_PORT} \
    +RTS -M1G -RTS
