#!/bin/sh

# Exports connection details for the self-hosted SimpleX relays.
# Other apps (especially simplex-chat / simplex-gateway for Hermes Agent)
# can opt-in to using these relays instead of (or in addition to) public ones.

# Note: Because we are Tailscale-first by default, the best addresses are usually
# the Tailscale MagicDNS names or 100.x IPs once Tailscale is connected.

export APP_SIMPLEX_RELAY_SMP_HOST="${APP_SIMPLEX_RELAY_SMP_IP:-simplex-relay_smp_1}"
export APP_SIMPLEX_RELAY_SMP_PORT="5223"

export APP_SIMPLEX_RELAY_XFTP_HOST="${APP_SIMPLEX_RELAY_XFTP_IP:-simplex-relay_xftp_1}"
export APP_SIMPLEX_RELAY_XFTP_PORT="443"

# Full addresses (users will usually want to replace with Tailscale MagicDNS)
export APP_SIMPLEX_RELAY_SMP_ADDRESS="smp://${APP_SIMPLEX_RELAY_SMP_HOST}:${APP_SIMPLEX_RELAY_SMP_PORT}"
export APP_SIMPLEX_RELAY_XFTP_ADDRESS="xftp://${APP_SIMPLEX_RELAY_XFTP_HOST}:${APP_SIMPLEX_RELAY_XFTP_PORT}"

echo "SimpleX Relay exports loaded (Tailscale-first):"
echo "  SMP:  ${APP_SIMPLEX_RELAY_SMP_HOST}:${APP_SIMPLEX_RELAY_SMP_PORT}"
echo "  XFTP: ${APP_SIMPLEX_RELAY_XFTP_HOST}:${APP_SIMPLEX_RELAY_XFTP_PORT}"
