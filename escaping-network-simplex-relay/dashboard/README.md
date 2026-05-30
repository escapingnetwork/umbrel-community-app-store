# SimpleX Relay Dashboard

This is the Go + HTMX management interface for the SimpleX Relay Umbrel app.

## Tech Stack

- Go 1.23 (standard library + chi router)
- HTMX for dynamic interactions
- Tailwind CSS (via CDN for now)
- Self-contained single binary

## Development

```bash
cd dashboard
go run ./cmd/server
```

The app expects the config/state directories at the paths defined in `main.go` (or override via volume mounts).

## Docker Build

The root `docker-compose.yml` builds this automatically:

```bash
docker compose build web
```

## Initialization Logic

The dashboard can run `smp-server init` and `xftp-server init` because the official binaries are copied into the image during the multi-stage build.

It writes directly to the mounted volumes (`/etc/opt/simplex`, etc.).
