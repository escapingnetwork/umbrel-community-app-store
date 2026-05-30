# SimpleX Chat Daemon for Umbrel (Gateway for Hermes Agent)
# Multi-arch (amd64 + arm64)

ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

LABEL org.opencontainers.image.title="SimpleX Chat Gateway"
LABEL org.opencontainers.image.description="Headless SimpleX Chat daemon with JSON API for Hermes Agent on Umbrel"
LABEL org.opencontainers.image.source="https://github.com/escapingnetwork/umbrel-community-app-store"
LABEL org.opencontainers.image.licenses="MPL-2.0"

# Install runtime dependencies + socat for the WS gateway proxy + tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    libsqlite3-0 \
    socat \
    python3 \
    dumb-init \
    file \
    gosu \
    bsdutils \
    expect \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for better security
RUN useradd --create-home --shell /bin/bash --uid 1000 simplex

# Set up data directory
ENV SIMPLEX_DATA_DIR=/data
RUN mkdir -p ${SIMPLEX_DATA_DIR} && chown -R simplex:simplex ${SIMPLEX_DATA_DIR}

WORKDIR /app

# Architecture mapping for prebuilt binaries
# Docker TARGETARCH: amd64 | arm64
# Simplex release naming: x86_64 | aarch64
ARG TARGETARCH
ARG SIMPLEX_VERSION=6.5.2

# Download the correct prebuilt static binary for the target architecture
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64)  ARCH_NAME="x86_64" ;; \
        arm64)  ARCH_NAME="aarch64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    BINARY_URL="https://github.com/simplex-chat/simplex-chat/releases/download/v${SIMPLEX_VERSION}/simplex-chat-ubuntu-22_04-${ARCH_NAME}"; \
    echo "Downloading simplex-chat v${SIMPLEX_VERSION} for ${ARCH_NAME}..."; \
    curl -fL --retry 5 --retry-delay 2 -o /usr/local/bin/simplex-chat "${BINARY_URL}"; \
    chmod +x /usr/local/bin/simplex-chat; \
    # Robust smoke test (many releases don't have a clean --version that exits 0)
    file /usr/local/bin/simplex-chat | grep -q "ELF"; \
    /usr/local/bin/simplex-chat -h 2>&1 | head -3 >/dev/null

# Copy entrypoint and web assets
COPY --chown=simplex:simplex entrypoint.sh /app/entrypoint.sh
COPY --chown=simplex:simplex web/ /app/web/

RUN chmod +x /app/entrypoint.sh

# Expose ports:
# 5225 - SimpleX JSON API WebSocket (via socat proxy, reachable from other Umbrel apps)
# 8080 - Simple status/info dashboard (for Umbrel "Open" button)
EXPOSE 5225 8080

# Healthcheck: verify both the proxy port is listening and simplex-chat process can respond to basic commands
HEALTHCHECK --interval=30s --timeout=10s --start-period=25s --retries=3 \
    CMD socat -u OPEN:/dev/null TCP:127.0.0.1:5225,connect-timeout=3 || exit 1

# Run as root so entrypoint can do mkdir/chown on mounted volumes.
# We drop privileges using gosu for the actual processes.
# Use dumb-init for proper signal handling (important for graceful shutdown)
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/app/entrypoint.sh"]
