# SimpleX Chat (Gateway / Daemon)

Headless **SimpleX Chat** daemon with JSON WebSocket API, designed primarily as a gateway for **Hermes Agent** (Nous Research) running on Umbrel.

This app is part of the Escaping Network community app store.

## Features

- Runs `simplex-chat` in server mode (`-p 5225`)
- Automatic "Hermes Gateway" bot profile creation on first start
- socat proxy so other containers on the Umbrel Docker network can reach the WebSocket API
- Clean dashboard with Hermes setup instructions
- Exports its address so other apps can easily connect

## Installation

Add the Escaping Network community app store in Umbrel, then install **SimpleX Chat**.

## Recommended Setup with Hermes Agent

1. Install this app + Hermes Agent.
2. In Hermes, set:

```env
SIMPLEX_WS_URL=ws://escaping-network-simplex-chat_app_1:5225
```

3. Use Hermes pairing flow (`hermes gateway pair`) or the setup wizard.

## Pairing with your own SimpleX Relay (opt-in)

If you also run the companion **SimpleX Relay** app from this store, you can configure Hermes (and this gateway) to use your private relays instead of public ones.

The Relay app exports:

- `APP_SIMPLEX_RELAY_SMP_ADDRESS`
- `APP_SIMPLEX_RELAY_XFTP_ADDRESS`

## Accessing the Daemon from Terminal (advanced)

```bash
docker exec -it escaping-network-simplex-chat_app_1 simplex-chat -d /data
```

## Development / Local Testing

The main container is built from the included `Dockerfile`.

Rebuild after changes:

```bash
docker compose build
docker compose up -d
```

## Publishing the Image

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/escapingnetwork/simplex-chat-daemon:v0.1.0 \
  --push .
```

Then pin the digest in `docker-compose.yml`.

## Credits

- SimpleX Chat: https://github.com/simplex-chat/simplex-chat
- Hermes Agent: https://github.com/NousResearch/hermes-agent
