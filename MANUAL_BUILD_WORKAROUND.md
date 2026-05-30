# Manual Build Workaround for SimpleX Apps on Umbrel

Because these apps currently use `build:` in docker-compose, the legacy installer on Umbrel Home often fails with errors like:

- `unable to prepare context: path ".../dashboard" not found`
- Or silent build failures.

Until we publish proper images, use this workaround to test on your own Umbrel.

---

## Step-by-step Workaround (Run on your Umbrel)

### 1. Build the images manually using the Terminal app

Open the **Terminal** app on your Umbrel and run:

```bash
# 1. Build the Gateway (simplex-chat daemon)
cd ~/umbrel/app-stores/escapingnetwork-umbrel-community-app-store-*/escaping-network-simplex-chat
docker build -t local/simplex-chat-daemon:local .

# 2. Build the Relay Dashboard
cd ~/umbrel/app-stores/escapingnetwork-umbrel-community-app-store-*/escaping-network-simplex-relay
docker build -t local/simplex-relay-dashboard:local ./dashboard
```

This will take a few minutes on the first run (especially on ARM).

### 2. Patch the installed app compose files (after failed install)

Even if installation "failed", Umbrel still creates the app data folder.

Run these commands:

```bash
# For the Gateway
sudo sed -i 's|build:|# build:  # disabled for manual testing|g' \
  ~/umbrel/app-data/escaping-network-simplex-chat/docker-compose.yml

sudo sed -i '/# build:  # disabled for manual testing/a\    image: local/simplex-chat-daemon:local' \
  ~/umbrel/app-data/escaping-network-simplex-chat/docker-compose.yml

# For the Relay
sudo sed -i 's|build:|# build:  # disabled for manual testing|g' \
  ~/umbrel/app-data/escaping-network-simplex-relay/docker-compose.yml

sudo sed -i '/# build:  # disabled for manual testing/a\    image: local/simplex-relay-dashboard:local' \
  ~/umbrel/app-data/escaping-network-simplex-relay/docker-compose.yml
```

### 3. Restart the apps

```bash
# Restart Gateway
docker compose -f ~/umbrel/app-data/escaping-network-simplex-chat/docker-compose.yml down
docker compose -f ~/umbrel/app-data/escaping-network-simplex-chat/docker-compose.yml up -d

# Restart Relay
docker compose -f ~/umbrel/app-data/escaping-network-simplex-relay/docker-compose.yml down
docker compose -f ~/umbrel/app-data/escaping-network-simplex-relay/docker-compose.yml up -d
```

### 4. Check logs

```bash
docker logs -f escaping-network-simplex-chat_app_1
docker logs -f escaping-network-simplex-relay_web_1
```

---

## After the Workaround

- You should be able to open both apps from the Umbrel dashboard.
- The Relay app should show the initialization wizard.
- The Gateway should show the Hermes instructions.

**Note**: Every time you update the app from the store, you will need to re-apply the sed patches above (until we switch to published images).

---

## Long-term Fix

We need to:

1. Merge the GitHub Actions workflow (`.github/workflows/build-simplex-images.yml`)
2. After it runs, update the real `docker-compose.yml` files to use `image:` instead of `build:`
3. Push the updated apps to the store

Would you like me to prepare the "published image" versions of the compose files now?
