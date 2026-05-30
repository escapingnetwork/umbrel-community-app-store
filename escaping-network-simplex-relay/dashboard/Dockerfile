# Multi-stage build for SimpleX Relay Dashboard
# Includes Go app + smp-server + xftp-server binaries

# --- Stage 1: Grab official server binaries ---
FROM simplexchat/smp-server:latest AS smp-bin
FROM simplexchat/xftp-server:latest AS xftp-bin

# --- Stage 2: Build the Go dashboard ---
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Install build deps
RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum* ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w" \
    -o /dashboard \
    ./cmd/server

# --- Stage 3: Final minimal runtime image ---
FROM alpine:3.19

LABEL org.opencontainers.image.title="SimpleX Relay Dashboard"
LABEL org.opencontainers.image.description="Management UI + initialization wizard for self-hosted SimpleX relays on Umbrel"
LABEL org.opencontainers.image.source="https://github.com/escapingnetwork/umbrel-community-app-store"
LABEL org.opencontainers.image.licenses="AGPL-3.0"

RUN apk add --no-cache ca-certificates tzdata

# Copy server binaries (so the dashboard can run init commands)
COPY --from=smp-bin  /usr/local/bin/smp-server  /usr/local/bin/smp-server
COPY --from=xftp-bin /usr/local/bin/xftp-server /usr/local/bin/xftp-server

# Copy our Go binary
COPY --from=builder /dashboard /usr/local/bin/dashboard

# Copy restart wrapper
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create directories that will be mounted
RUN mkdir -p /etc/opt/simplex /var/opt/simplex \
             /etc/opt/simplex-xftp /var/opt/simplex-xftp /srv/xftp

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
