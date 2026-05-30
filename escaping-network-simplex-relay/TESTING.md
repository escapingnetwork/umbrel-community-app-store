# Testing SimpleX Relay on Umbrel

## Quick Local Test (on your Umbrel Home)

1. On your Umbrel machine, copy this folder into your community app store directory:

```bash
rsync -av --delete escaping-network-simplex-relay/ \
  ~/umbrel/app-stores/escapingnetwork-umbrel-community-app-store-*/escaping-network-simplex-relay/
```

2. Restart the app store or run:

```bash
sudo ~/umbrel/scripts/repo update
```

3. Install "SimpleX Relay" from your community store.

4. After install, open the app and use the initialization wizard.

## Building the Dashboard Image Manually (if needed)

If the build doesn't trigger automatically:

```bash
cd ~/umbrel/app-data/escaping-network-simplex-relay/dashboard
docker build -t escaping-network/simplex-relay-dashboard:local .
```

Then temporarily edit the `docker-compose.yml` in `~/umbrel/app-data/escaping-network-simplex-relay/` to use the local image.

## Verifying Initialization

After init, you should see:

- `smp-server.ini` and `fingerprint` in `smp/config/`
- `xftp-server.ini` and `fingerprint` in `xftp/config/`

## Connecting from Hermes / SimpleX Chat

See the main README for integration details.
