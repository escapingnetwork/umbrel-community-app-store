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

# Run as root initially so we can create/chown directories on mounted volumes
mkdir -p "${DATA_DIR}"
chown -R simplex:simplex /data 2>/dev/null || true

cd "${DATA_DIR}"

# One-time bot profile creation (only if DB doesn't exist)
if [ ! -f "${DATA_DIR}/simplex_v1_chat.db" ]; then
    echo "[entrypoint] No existing database found. Creating bot profile..."
    # Use 'script' here too, because the creation path can also trigger the terminal library
    TERM=dumb script -q -c "gosu simplex /usr/local/bin/simplex-chat \
        -d '${DATA_DIR}' \
        --create-bot-display-name 'Hermes Gateway' \
        --create-bot-allow-files" /dev/null || true
    sleep 5
fi

# Start sidecar services (can run as root)
echo "[entrypoint] Starting socat proxy on 0.0.0.0:${WS_PORT}..."
socat TCP-LISTEN:${WS_PORT},fork,reuseaddr,bind=0.0.0.0 \
      TCP:127.0.0.1:${WS_PORT} &

echo "[entrypoint] Starting web dashboard on 0.0.0.0:${WEB_PORT}..."
cd /app/web
python3 -m http.server "${WEB_PORT}" &

# Run simplex-chat in a restart loop.
# We use `script` to fake a TTY (prevents Prelude.undefined terminal crash in Docker)
# and TERM=dumb for extra safety.
echo "[entrypoint] Starting simplex-chat daemon (with auto-restart)..."
while true; do
    TERM=dumb script -q -c "gosu simplex /usr/local/bin/simplex-chat -d '${DATA_DIR}' -p ${WS_PORT}" /dev/null || true

    echo "[entrypoint] simplex-chat exited. Restarting in 5 seconds..."
    sleep 5
done
