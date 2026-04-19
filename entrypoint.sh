#!/bin/sh
set -e

if [ -z "${TS_AUTHKEY}" ]; then
    echo "ERROR: TS_AUTHKEY is not set." >&2
    exit 1
fi

mkdir -p /var/run/tailscale /var/lib/tailscale

# Use userspace networking — Railway containers don't expose /dev/net/tun
tailscaled \
    --tun=userspace-networking \
    --state=/var/lib/tailscale/tailscaled.state \
    --socket=/var/run/tailscale/tailscaled.sock \
    &

TAILSCALED_PID=$!

# Give tailscaled a moment to start
sleep 2

tailscale up \
    --authkey="${TS_AUTHKEY}" \
    --hostname="${TS_HOSTNAME:-railway-exit-node}" \
    --advertise-exit-node \
    ${TS_EXTRA_ARGS:-}

echo ""
echo "Exit node is up. Remember to approve it in the Tailscale admin console:"
echo "  https://login.tailscale.com/admin/machines"
echo ""
tailscale status

# Graceful shutdown
trap "tailscale down; kill ${TAILSCALED_PID}" TERM INT

wait ${TAILSCALED_PID}
