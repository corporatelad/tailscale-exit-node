#!/bin/sh
set -e

if [ -z "${TS_AUTHKEY}" ]; then
    echo "ERROR: TS_AUTHKEY is not set." >&2
    exit 1
fi

TS_STATE_DIR="${TS_STATE_DIR:-/var/lib/tailscale}"
TS_SOCKET=/var/run/tailscale/tailscaled.sock
WATCHDOG_INTERVAL="${TS_WATCHDOG_INTERVAL:-30}"
WATCHDOG_MAX_FAILS="${TS_WATCHDOG_MAX_FAILS:-3}"

mkdir -p /var/run/tailscale "${TS_STATE_DIR}"

echo "Tailscale version: $(tailscale version | head -n1)"

# Use userspace networking — Railway containers don't expose /dev/net/tun
tailscaled \
    --tun=userspace-networking \
    --state="${TS_STATE_DIR}/tailscaled.state" \
    --socket="${TS_SOCKET}" \
    &

TAILSCALED_PID=$!

# On stop, just kill tailscaled. Don't run `tailscale down`: it persists
# WantRunning=false to the state file and buys nothing on shutdown.
trap 'kill ${TAILSCALED_PID} 2>/dev/null; exit 0' TERM INT

# Wait for tailscaled to accept connections (up to ~30s)
i=0
until tailscale --socket="${TS_SOCKET}" status --json >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 30 ] || ! kill -0 "${TAILSCALED_PID}" 2>/dev/null; then
        echo "ERROR: tailscaled did not start." >&2
        exit 1
    fi
    sleep 1
done

tailscale --socket="${TS_SOCKET}" up \
    --authkey="${TS_AUTHKEY}" \
    --hostname="${TS_HOSTNAME:-railway-exit-node}" \
    --advertise-exit-node \
    ${TS_EXTRA_ARGS:-}

echo ""
echo "Exit node is up. If this is a new machine, approve it in the Tailscale admin console:"
echo "  https://login.tailscale.com/admin/machines"
echo ""
tailscale --socket="${TS_SOCKET}" status

# Watchdog: if tailscale is not Running for WATCHDOG_MAX_FAILS checks in a row
# (stopped, logged out, key expired...) or tailscaled dies, exit non-zero so
# Railway's restart policy brings up a fresh container.
fails=0
while kill -0 "${TAILSCALED_PID}" 2>/dev/null; do
    # sleep in the background so the TERM trap fires immediately
    sleep "${WATCHDOG_INTERVAL}" &
    wait $!

    state=$(tailscale --socket="${TS_SOCKET}" status --json 2>/dev/null | jq -r '.BackendState // empty' || true)
    if [ "${state}" = "Running" ]; then
        fails=0
    else
        fails=$((fails + 1))
        echo "watchdog: tailscale state is '${state:-unknown}' (${fails}/${WATCHDOG_MAX_FAILS})" >&2
        if [ "${fails}" -ge "${WATCHDOG_MAX_FAILS}" ]; then
            echo "watchdog: giving up, exiting so Railway restarts the container" >&2
            kill "${TAILSCALED_PID}" 2>/dev/null || true
            exit 1
        fi
    fi
done

echo "ERROR: tailscaled exited unexpectedly." >&2
exit 1
