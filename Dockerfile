FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    iptables \
    iproute2 \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Tailscale from official repo. Bump this when Tailscale ships a
# release (the admin console flags outdated nodes); set it to an empty
# string to install whatever is latest at build time.
ARG TAILSCALE_VERSION=1.104.1
RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
        -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list \
        -o /etc/apt/sources.list.d/tailscale.list \
    && apt-get update && apt-get install -y --no-install-recommends \
        "tailscale${TAILSCALE_VERSION:+=${TAILSCALE_VERSION}}" \
    && tailscale version \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
