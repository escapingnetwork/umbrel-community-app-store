#!/bin/bash
set -euo pipefail

# SimpleX Relay Initialization Script for Umbrel
# This script helps initialize both SMP and XFTP servers with good defaults
# for private / Tailscale-first deployments.

DATA_DIR="${APP_DATA_DIR:-/data}"
SMP_CONFIG_DIR="${DATA_DIR}/smp/config"
SMP_STATE_DIR="${DATA_DIR}/smp/state"
XFTP_CONFIG_DIR="${DATA_DIR}/xftp/config"
XFTP_STATE_DIR="${DATA_DIR}/xftp/state"
XFTP_FILES_DIR="${DATA_DIR}/xftp/files"

echo "=================================================="
echo "  SimpleX Relay - Initialization"
echo "=================================================="

mkdir -p "$SMP_CONFIG_DIR" "$SMP_STATE_DIR" "$XFTP_CONFIG_DIR" "$XFTP_STATE_DIR" "$XFTP_FILES_DIR"

# -------------------------------------------------------------------
# Ask user for basic configuration
# -------------------------------------------------------------------
echo ""
read -rp "Enter server hostname or Tailscale MagicDNS name (e.g. umbrel.yourname.ts.net): " SERVER_HOST
if [ -z "$SERVER_HOST" ]; then
    echo "Hostname is required."
    exit 1
fi

read -rp "Require password to create new queues? (y/N): " REQUIRE_PASS
CREATE_PASS=""
if [[ "$REQUIRE_PASS" =~ ^[Yy] ]]; then
    read -rsp "Enter password for creating queues: " CREATE_PASS
    echo ""
fi

read -rp "Enable store log (recommended)? (Y/n): " ENABLE_STORE_LOG
STORE_LOG_FLAG="-l"
if [[ "$ENABLE_STORE_LOG" =~ ^[Nn] ]]; then
    STORE_LOG_FLAG=""
fi

echo ""
echo "Initializing servers with host: $SERVER_HOST"
echo ""

# -------------------------------------------------------------------
# Initialize SMP server
# -------------------------------------------------------------------
echo "→ Initializing SMP server..."
docker exec simplex-relay_smp_1 smp-server init -y \
    $STORE_LOG_FLAG \
    --no-password \
    -n "$SERVER_HOST" \
    ${CREATE_PASS:+--password "$CREATE_PASS"} || true

echo "SMP server initialized."

# -------------------------------------------------------------------
# Initialize XFTP server
# -------------------------------------------------------------------
echo "→ Initializing XFTP server..."
docker exec simplex-relay_xftp_1 xftp-server init -y \
    --quota 10gb \
    -n "$SERVER_HOST" || true

echo "XFTP server initialized."

echo ""
echo "=================================================="
echo "Initialization complete!"
echo ""
echo "Your servers are now configured for: $SERVER_HOST"
echo ""
echo "Next steps:"
echo "  1. Restart the app from the Umbrel dashboard"
echo "  2. Check the dashboard for the full server addresses + fingerprints"
echo "  3. (Recommended) Use these addresses via Tailscale"
echo "=================================================="
