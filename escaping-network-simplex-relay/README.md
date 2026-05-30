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

## Images

The dashboard is automatically built and published by GitHub Actions to:

`ghcr.io/escapingnetwork/simplex-relay-dashboard`

## Development / Local Testing

For local development you can build the dashboard yourself:

```bash
docker build -t local/simplex-relay-dashboard:local ./dashboard
```

Then temporarily change the `image:` line in `docker-compose.yml`.

## Releasing New Versions

1. Push changes to the repo.
2. GitHub Actions will build and push new images.
3. Update the `image:` line in `docker-compose.yml` with the new tag + full digest from the workflow run.
4. Commit and push the updated `docker-compose.yml`.

## Credits

- Servers: https://github.com/simplex-chat/simplexmq
- Umbrel Community App Store template
