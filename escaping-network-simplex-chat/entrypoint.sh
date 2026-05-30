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
    # Use unbuffer + TERM=dumb, and pipe "y" in case it ever prompts during creation.
    yes y | TERM=dumb unbuffer -p gosu simplex /usr/local/bin/simplex-chat \
        -d "${DATA_DIR}" \
        --create-bot-display-name "Hermes Gateway" \
        --create-bot-allow-files || true
    sleep 5
fi

# Start socat proxy in background
echo "[entrypoint] Starting socat proxy on 0.0.0.0:${WS_PORT}..."
socat TCP-LISTEN:${WS_PORT},fork,reuseaddr,bind=0.0.0.0 \
      TCP:127.0.0.1:${WS_PORT} &

# Start a background process that keeps restarting the simplex-chat daemon
# with exponential backoff. This reduces log spam when the binary hits
# transient crashes (like the current "divide by zero" in v6.5.2.0).
(
  echo "[entrypoint] Starting simplex-chat daemon (with auto-restart)..."
  RESTART_DELAY=5
  while true; do
      yes y | TERM=dumb unbuffer -p gosu simplex /usr/local/bin/simplex-chat \
          -d "${DATA_DIR}" \
          -p ${WS_PORT} || true

      echo "[entrypoint] simplex-chat exited. Restarting in ${RESTART_DELAY}s..."
      sleep $RESTART_DELAY

      # Exponential backoff, max 60s
      RESTART_DELAY=$((RESTART_DELAY * 2))
      if [ $RESTART_DELAY -gt 60 ]; then
          RESTART_DELAY=60
      fi
  done
) &

# Run the web dashboard in the foreground.
# This is what keeps the container alive and allows the Umbrel proxy to connect.
echo "[entrypoint] Starting web dashboard on 0.0.0.0:${WEB_PORT}..."
cd /app/web
exec python3 -m http.server "${WEB_PORT}"
