#!/bin/bash
set -euo pipefail

# SimpleX Chat Daemon + Gateway Proxy + Web UI for Umbrel
# Designed specifically as a gateway for Hermes Agent (Nous Research)

# Use a subdirectory so database files are nicely namespaced inside the volume
DATA_DIR="${SIMPLEX_DATA_DIR:-/data}/simplex"
WS_PORT=5225
WEB_PORT=8080

echo "=================================================="
echo "  SimpleX Chat Daemon (Umbrel Gateway)"
echo "  Data directory: ${DATA_DIR}"
echo "=================================================="

# Run as root (entrypoint starts as root because we removed USER in Dockerfile)
# This allows us to create directories on volumes mounted by Umbrel (which are often root-owned).
mkdir -p "${DATA_DIR}"
chown -R simplex:simplex /data

cd "${DATA_DIR}"

# Auto-create bot profile on first run
if [ ! -f "${DATA_DIR}/simplex_v1_chat.db" ]; then
    echo "[entrypoint] No existing database found. Creating bot profile..."
    TERM=dumb gosu simplex /usr/local/bin/simplex-chat \
        -d "${DATA_DIR}" \
        --create-bot-display-name "Hermes Gateway" \
        --create-bot-allow-files || true
    sleep 3
fi

# Start sidecar services in background (fine to run as root)
echo "[entrypoint] Starting socat proxy on 0.0.0.0:${WS_PORT}..."
socat TCP-LISTEN:${WS_PORT},fork,reuseaddr,bind=0.0.0.0 \
      TCP:127.0.0.1:${WS_PORT} &

echo "[entrypoint] Starting web dashboard on 0.0.0.0:${WEB_PORT}..."
cd /app/web
python3 -m http.server "${WEB_PORT}" &

# Run the main daemon with TERM=dumb (prevents terminal library crashes in Docker)
# and wrap in a loop so the container stays alive even if the binary exits temporarily.
echo "[entrypoint] Starting simplex-chat daemon (with auto-restart)..."
while true; do
    TERM=dumb gosu simplex /usr/local/bin/simplex-chat \
        -d "${DATA_DIR}" \
        -p ${WS_PORT} || true

    echo "[entrypoint] simplex-chat exited. Restarting in 5 seconds..."
    sleep 5
done
