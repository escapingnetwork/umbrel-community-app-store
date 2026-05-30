# Testing SimpleX Chat (Gateway) on Umbrel

## Quick Local Test

```bash
rsync -av --delete escaping-network-simplex-chat/ \
  ~/umbrel/app-stores/escapingnetwork-umbrel-community-app-store-*/escaping-network-simplex-chat/
```

Then update the app store and install "SimpleX Chat".

## Verifying the Daemon

```bash
docker logs -f escaping-network-simplex-chat_app_1
```

The WS API should be reachable internally at:

```
ws://escaping-network-simplex-chat_app_1:5225
```

## Hermes Configuration

```env
SIMPLEX_WS_URL=ws://escaping-network-simplex-chat_app_1:5225
```

## Pairing

Use `hermes gateway pair` or the Hermes setup wizard.
