#!/bin/bash
set -euo pipefail

# SimpleX Chat Daemon + Gateway Proxy + Web UI for Umbrel
# Designed specifically as a gateway for Hermes Agent (Nous Research)

DATA_DIR="${SIMPLEX_DATA_DIR:-/data}"
WS_INTERNAL_PORT=5225          # The real simplex-chat listens here (localhost only)
WS_GATEWAY_PORT=5225           # What other containers (Hermes) connect to (0.0.0.0 via socat)
WEB_PORT=8080

echo "=================================================="
echo "  SimpleX Chat Daemon (Umbrel Gateway)"
echo "  Data directory: ${DATA_DIR}"
echo "=================================================="

mkdir -p "${DATA_DIR}"
cd "${DATA_DIR}"

# -------------------------------------------------------------------
# 1. Start the SimpleX Chat daemon (binds only to 127.0.0.1 by design)
# -------------------------------------------------------------------
echo "[entrypoint] Starting simplex-chat daemon on 127.0.0.1:${WS_INTERNAL_PORT}..."

# Auto-create a clean bot profile on first run if no database exists
if [ ! -f "${DATA_DIR}/simplex_v1_chat.db" ]; then
    echo "[entrypoint] No existing database found. Creating bot profile..."
    # The --create-bot-* flags only work on first initialization
    /usr/local/bin/simplex-chat \
        -d "${DATA_DIR}" \
        --create-bot-display-name "Hermes Gateway" \
        --create-bot-allow-files \
        +RTS -M1G -RTS \
        >/dev/null 2>&1 || true

    # Give it a moment to finish initialization
    sleep 2
fi

# Start the actual daemon in the background
/usr/local/bin/simplex-chat \
    -d "${DATA_DIR}" \
    -p "${WS_INTERNAL_PORT}" \
    +RTS -M1G -RTS \
    >/dev/null 2>&1 &

SIMPLEX_PID=$!
echo "[entrypoint] simplex-chat started (PID: ${SIMPLEX_PID})"

# -------------------------------------------------------------------
# 2. Start socat proxy so other containers can reach the WS API
#    (socat listens on 0.0.0.0 and forwards to localhost)
# -------------------------------------------------------------------
echo "[entrypoint] Starting socat gateway proxy on 0.0.0.0:${WS_GATEWAY_PORT} -> 127.0.0.1:${WS_INTERNAL_PORT}"

socat TCP-LISTEN:${WS_GATEWAY_PORT},fork,reuseaddr,bind=0.0.0.0 \
      TCP:127.0.0.1:${WS_INTERNAL_PORT} >/dev/null 2>&1 &

SOCAT_PID=$!
echo "[entrypoint] socat proxy started (PID: ${SOCAT_PID})"

# -------------------------------------------------------------------
# 3. Start simple web dashboard (Python http.server is sufficient for v1)
# -------------------------------------------------------------------
echo "[entrypoint] Starting web dashboard on 0.0.0.0:${WEB_PORT}"

cd /app/web
python3 -m http.server "${WEB_PORT}" >/dev/null 2>&1 &

WEB_PID=$!
echo "[entrypoint] Web server started (PID: ${WEB_PID})"

# -------------------------------------------------------------------
# 4. Health / readiness wait + graceful shutdown handling
# -------------------------------------------------------------------
cleanup() {
    echo ""
    echo "[entrypoint] Shutting down..."
    kill ${WEB_PID} 2>/dev/null || true
    kill ${SOCAT_PID} 2>/dev/null || true
    kill ${SIMPLEX_PID} 2>/dev/null || true
    wait ${SIMPLEX_PID} 2>/dev/null || true
    echo "[entrypoint] Shutdown complete."
    exit 0
}

trap cleanup SIGTERM SIGINT

# -------------------------------------------------------------------
# 5. Readiness wait — make sure the proxy is actually accepting connections
#    before we declare the container healthy
# -------------------------------------------------------------------
echo "[entrypoint] Waiting for WS gateway to become ready..."
for i in $(seq 1 30); do
    if socat -u OPEN:/dev/null TCP:127.0.0.1:${WS_GATEWAY_PORT},connect-timeout=1 2>/dev/null; then
        break
    fi
    sleep 1
    if [ $i -eq 30 ]; then
        echo "[entrypoint] WARNING: Gateway did not become ready in time"
    fi
done

echo ""
echo "[entrypoint] =================================================="
echo "[entrypoint] SimpleX Gateway is ready!"
echo "[entrypoint] Web UI:          http://0.0.0.0:${WEB_PORT}"
echo "[entrypoint] WS Gateway (for Hermes): ws://<container>:${WS_GATEWAY_PORT}"
echo "[entrypoint] Internal only:   ws://127.0.0.1:${WS_INTERNAL_PORT}"
echo "[entrypoint] =================================================="
echo ""

# Wait for the main simplex process (keeps container alive)
wait ${SIMPLEX_PID}
