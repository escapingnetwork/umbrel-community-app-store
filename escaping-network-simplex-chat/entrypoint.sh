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

# Start a background process that keeps restarting the simplex-chat daemon
# with exponential backoff. This reduces log spam when the binary hits
# transient crashes (like the "divide by zero" in v6.5.2.0; we are now running 6.5.3).
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

# Wait for the daemon's localhost listener (it binds only to 127.0.0.1 by design for security).
# The socat proxy will then expose it on 0.0.0.0 so other Docker containers can reach it
# via the container's DNS name on the Umbrel network (e.g. escaping-network-simplex-chat_app_1:5225).
echo "[entrypoint] Waiting for simplex-chat to listen on 127.0.0.1:${WS_PORT}..."
for i in {1..45}; do
    if bash -c "echo > /dev/tcp/127.0.0.1/${WS_PORT}" 2>/dev/null; then
        echo "[entrypoint] Daemon ready on 127.0.0.1:${WS_PORT}"
        break
    fi
    sleep 1
    if [ "$i" -eq 45 ]; then
        echo "[entrypoint] WARNING: Daemon port not detected after 45s, starting proxy anyway (may fail until daemon binds)"
    fi
done

# Start socat proxy in background (with auto-restart). This makes the WS API reachable
# from other containers on the Docker network at ws://<container>:5225 (the "escaping" part).
(
  echo "[entrypoint] Starting socat proxy on 0.0.0.0:${WS_PORT} -> 127.0.0.1:${WS_PORT} (with auto-restart)..."
  while true; do
      socat TCP-LISTEN:${WS_PORT},fork,reuseaddr,bind=0.0.0.0 \
            TCP:127.0.0.1:${WS_PORT},keepalive || true
      echo "[entrypoint] socat proxy exited. Restarting in 2s..."
      sleep 2
  done
) &

# Run the web dashboard in the foreground.
# This is what keeps the container alive and allows the Umbrel proxy to connect.
echo "[entrypoint] Starting web dashboard on 0.0.0.0:${WEB_PORT}..."
cd /app/web
exec python3 -m http.server "${WEB_PORT}"
