FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    iptables \
    iproute2 \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Tailscale from official repo
RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
        -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list \
        -o /etc/apt/sources.list.d/tailscale.list \
    && apt-get update && apt-get install -y --no-install-recommends tailscale \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
