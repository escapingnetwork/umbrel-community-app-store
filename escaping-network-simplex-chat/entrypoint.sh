#!/bin/bash
set -euo pipefail

# SimpleX Chat Daemon + Gateway Proxy + Web UI for Umbrel
# Designed specifically as a gateway for Hermes Agent (Nous Research)

# Use a subdirectory so database files are nicely namespaced inside the volume.
# Note: Recent simplex-chat versions sometimes create DBs at the parent level.
DATA_DIR="${SIMPLEX_DATA_DIR:-/data}/simplex"
WS_PORT=5225
WEB_PORT=8080

# Kill any leftover processes from previous failed/stuck create attempts.
# The yes|unbuffer|gosu pipeline is fragile when the binary crashes ("divide by zero").
cleanup_stuck_processes() {
    echo "[entrypoint] Cleaning up any stuck create/daemon processes..."
    pkill -f 'create-bot-display-name' 2>/dev/null || true
    pkill -f 'unbuffer.*simplex-chat' 2>/dev/null || true
    pkill -f 'yes y.*simplex-chat' 2>/dev/null || true
    # Give them a moment to die
    sleep 1
    # Also kill any lingering simplex user processes that look stuck
    pkill -u simplex 2>/dev/null || true
    sleep 1
}

echo "=================================================="
echo "  SimpleX Chat Daemon (Umbrel Gateway)"
echo "  Data directory: ${DATA_DIR}"
echo "=================================================="

# Run as root initially so we can create/chown directories on mounted volumes
mkdir -p "${DATA_DIR}"
chown -R simplex:simplex /data 2>/dev/null || true

cd "${DATA_DIR}"

# Start the web dashboard *early* in the background so the Umbrel "Open" button
# (and app_proxy) can connect immediately.
echo "[entrypoint] Starting web dashboard early on 0.0.0.0:${WEB_PORT} (background)..."
(
  cd /app/web
  python3 -m http.server "${WEB_PORT}" >>/tmp/webserver.log 2>&1
) &
WEB_PID=$!

# Start the daemon restart loop *early* in background.
# This is the core of the gateway. It must run independently of the (optional)
# one-time profile creation.
(
  echo "[entrypoint] Starting simplex-chat daemon (with auto-restart)..."
  RESTART_DELAY=5
  while true; do
      cleanup_stuck_processes
      yes y | TERM=dumb unbuffer -p gosu simplex /usr/local/bin/simplex-chat \
          -d "${DATA_DIR}" \
          -p ${WS_PORT} || true

      echo "[entrypoint] simplex-chat exited (divide by zero or other transient?). Restarting in ${RESTART_DELAY}s..."
      sleep $RESTART_DELAY

      RESTART_DELAY=$((RESTART_DELAY * 2))
      if [ $RESTART_DELAY -gt 60 ]; then
          RESTART_DELAY=60
      fi
  done
) &

# One-time bot profile creation — run in background with its own hard timeout.
# This is best-effort and must never block the daemon loop.
if [ ! -f "${DATA_DIR}/simplex_chat.db" ] && [ ! -f "${DATA_DIR}/simplex_agent.db" ] && \
   [ ! -f "/data/simplex_chat.db" ] && [ ! -f "/data/simplex_agent.db" ]; then
    (
        echo "[entrypoint] Starting background bot profile creation (hard timeout)..."
        cleanup_stuck_processes
        set +e
        timeout --kill-after=10 80 bash -c '
            set -euo pipefail
            yes y | TERM=dumb unbuffer -p gosu simplex /usr/local/bin/simplex-chat \
                -d "'"${DATA_DIR}"'" \
                --create-bot-display-name "Hermes Gateway" \
                --create-bot-allow-files
        ' || true
        set -e
        cleanup_stuck_processes
        echo "[entrypoint] Background bot profile creation finished (best effort)."
    ) &
fi

# Wait (with timeout) for the daemon's listener.
# We no longer assume it only binds to 127.0.0.1.
echo "[entrypoint] Waiting (max 60s) for simplex-chat to listen on port ${WS_PORT}..."
for i in {1..60}; do
    if bash -c "echo > /dev/tcp/127.0.0.1/${WS_PORT}" 2>/dev/null || \
       bash -c "echo > /dev/tcp/0.0.0.0/${WS_PORT}" 2>/dev/null; then
        echo "[entrypoint] ✓ Daemon is listening on port ${WS_PORT}"
        echo "[entrypoint] ✓ READY FOR HERMES / external WebSocket clients"
        echo "[entrypoint]   Connect using: ws://escaping-network-simplex-chat_app_1:${WS_PORT}"
        break
    fi
    sleep 1
    if [ "$i" -eq 60 ]; then
        echo "[entrypoint] WARNING: No listener on port ${WS_PORT} after 60s."
    fi
done

# Start socat proxy *only if needed*.
# If simplex-chat is already listening on 0.0.0.0:5225 (which happens in some versions/configs),
# we skip the proxy to avoid "address already in use".
if ss -tlnp 2>/dev/null | grep -q ":${WS_PORT}.*0.0.0.0" || \
   netstat -tlnp 2>/dev/null | grep -q ":${WS_PORT}.*0.0.0.0"; then
    echo "[entrypoint] simplex-chat is already listening on 0.0.0.0:${WS_PORT} — skipping socat proxy."
else
    echo "[entrypoint] Starting socat proxy on 0.0.0.0:${WS_PORT} -> 127.0.0.1:${WS_PORT} (with auto-restart)..."
    (
      while true; do
          socat TCP-LISTEN:${WS_PORT},fork,reuseaddr,bind=0.0.0.0 \
                TCP:127.0.0.1:${WS_PORT},keepalive || true
          echo "[entrypoint] socat proxy exited. Restarting in 2s..."
          sleep 2
      done
    ) &
fi

# Keep the container alive. The early web server is already running in background.
# If it ever dies, fall back to exec'ing it again (should not happen).
echo "[entrypoint] Web dashboard should already be reachable on :${WEB_PORT}. Keeping container alive..."
wait $WEB_PID || true
echo "[entrypoint] Web server exited, restarting it..."
cd /app/web
exec python3 -m http.server "${WEB_PORT}"
