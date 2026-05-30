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

# Start the web dashboard *early* in the background so the Umbrel "Open" button
# (and app_proxy) can connect immediately. This prevents "connection refused"
# while the (potentially slow or crashy) daemon + bot creation + port wait happens.
echo "[entrypoint] Starting web dashboard early on 0.0.0.0:${WEB_PORT} (background)..."
(
  cd /app/web
  python3 -m http.server "${WEB_PORT}" >>/tmp/webserver.log 2>&1
) &
WEB_PID=$!

# One-time bot profile creation (only if no modern DB exists).
# Note: simplex-chat v6.5.3+ uses simplex_chat.db + simplex_agent.db (not the old simplex_v1_chat.db).
if [ ! -f "${DATA_DIR}/simplex_chat.db" ] && [ ! -f "${DATA_DIR}/simplex_agent.db" ]; then
    echo "[entrypoint] No existing database found. Creating bot profile..."
    # Use unbuffer + TERM=dumb, and pipe "y" in case it ever prompts during creation.
    yes y | TERM=dumb unbuffer -p gosu simplex /usr/local/bin/simplex-chat \
        -d "${DATA_DIR}" \
        --create-bot-display-name "Hermes Gateway" \
        --create-bot-allow-files || true
    sleep 3
fi

# Start a background process that keeps restarting the simplex-chat daemon
# with exponential backoff. "divide by zero" and other transient crashes have
# been observed even in 6.5.3 during certain startup paths.
(
  echo "[entrypoint] Starting simplex-chat daemon (with auto-restart)..."
  RESTART_DELAY=5
  while true; do
      yes y | TERM=dumb unbuffer -p gosu simplex /usr/local/bin/simplex-chat \
          -d "${DATA_DIR}" \
          -p ${WS_PORT} || true

      echo "[entrypoint] simplex-chat exited (divide by zero or other transient?). Restarting in ${RESTART_DELAY}s..."
      sleep $RESTART_DELAY

      # Exponential backoff, max 60s
      RESTART_DELAY=$((RESTART_DELAY * 2))
      if [ $RESTART_DELAY -gt 60 ]; then
          RESTART_DELAY=60
      fi
  done
) &

# Wait (with timeout) for the daemon's localhost listener so we can bring up the
# socat proxy for other containers. This no longer blocks the web UI.
echo "[entrypoint] Waiting (max 45s) for simplex-chat to listen on 127.0.0.1:${WS_PORT}..."
for i in {1..45}; do
    if bash -c "echo > /dev/tcp/127.0.0.1/${WS_PORT}" 2>/dev/null; then
        echo "[entrypoint] Daemon ready on 127.0.0.1:${WS_PORT}"
        break
    fi
    sleep 1
    if [ "$i" -eq 45 ]; then
        echo "[entrypoint] WARNING: Daemon port not detected after 45s. WS gateway may not be ready yet for other apps (Hermes etc.). Web UI is still available."
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

# Keep the container alive. The early web server is already running in background.
# If it ever dies, fall back to exec'ing it again (should not happen).
echo "[entrypoint] Web dashboard should already be reachable on :${WEB_PORT}. Keeping container alive..."
wait $WEB_PID || true
echo "[entrypoint] Web server exited, restarting it..."
cd /app/web
exec python3 -m http.server "${WEB_PORT}"
