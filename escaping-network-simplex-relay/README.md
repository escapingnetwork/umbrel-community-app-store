# SimpleX Relay

Self-hosted **SMP** + **XFTP** relays for SimpleX Chat on Umbrel, with a focus on private Tailscale access and a guided setup experience.

This app is part of the Escaping Network community app store.

## Features

- Official `simplexchat/smp-server` and `xftp-server`
- Go + HTMX web dashboard with initialization wizard
- Tailscale-first design (recommended)
- Exports relay addresses for use by other apps (e.g. SimpleX Chat Gateway for Hermes Agent)
- Persistent config and state

## Installation (via this store)

1. Add this community app store in your Umbrel if you haven't:
   - App Store → ⋮ → Community App Stores → Add → `https://github.com/escapingnetwork/umbrel-community-app-store.git`

2. Search for **SimpleX Relay** and install.

## First-time Setup (Important)

After installing:

1. Open the app.
2. Use the **Initialization Wizard** in the dashboard (recommended), or run the helper script via Umbrel Terminal:

```bash
cd ~/umbrel/app-data/escaping-network-simplex-relay
./scripts/init-relay.sh
```

When asked for hostname, use your **Tailscale MagicDNS** name (e.g. `umbrel.yourname.ts.net`) for the best private experience.

## Recommended: Use with Tailscale

- Install the official **Tailscale** app on your Umbrel.
- After initializing the relays with your Tailscale hostname, access them from any device on the same tailnet.
- No port forwarding or public domain required.

## Integration with SimpleX Chat Gateway

This app exports the following variables so the companion **SimpleX Chat** (Gateway) app can opt-in to using your private relays:

- `APP_SIMPLEX_RELAY_SMP_ADDRESS`
- `APP_SIMPLEX_RELAY_XFTP_ADDRESS`

## Development / Local Testing

The dashboard is built from `./dashboard` (Go + HTMX).

To rebuild the dashboard image while testing:

```bash
docker compose build web
docker compose up -d web
```

## Publishing Images (for store releases)

Build and push the dashboard:

```bash
cd dashboard
docker buildx build --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/escapingnetwork/simplex-relay-dashboard:v0.1.0 \
  --push .
```

Then update `docker-compose.yml` to use the published image + digest instead of `build:`.

## Credits

- Servers: https://github.com/simplex-chat/simplexmq
- Umbrel Community App Store template
