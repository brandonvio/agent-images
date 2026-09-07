#!/bin/bash
# Ephemeral one-shot CI job runner: start dockerd, register, run one job, exit.
set -euo pipefail

: "${RUNNER_SERVER_URL:?RUNNER_SERVER_URL required}"
: "${RUNNER_API_TOKEN:?RUNNER_API_TOKEN required}"
# Label advertises which runs-on this container satisfies, and (docker://IMG)
# the image jobs execute inside. Override via env to change the default job
# image.
: "${RUNNER_LABELS:=ubuntu-latest:docker://catthehacker/ubuntu:act-22.04}"
# Admin endpoint that mints a single-use registration token. Override if your
# forge exposes it elsewhere.
: "${RUNNER_REGISTER_PATH:=/api/v1/admin/actions/runners}"

export DOCKER_HOST="unix:///var/run/docker.sock"

log() { echo "[entrypoint] $*"; }

# 1. Start dockerd. This daemon is privileged; the isolation boundary is
#    whatever your platform puts around this container, not the daemon itself.
log "starting dockerd..."
# --mtu must not exceed the MTU of the network this container is attached to.
# When it does, the docker0 bridge fragments and large image-layer packets
# stall the pull. 1450 suits most overlay networks; override for a flat bridge.
dockerd --host="${DOCKER_HOST}" --group=docker --mtu="${DOCKERD_MTU:-1450}" >/var/log/dockerd.log 2>&1 &

log "waiting for dockerd..."
for _ in $(seq 1 60); do
  if docker info >/dev/null 2>&1; then break; fi
  sleep 1
done
if ! docker info >/dev/null 2>&1; then
  log "dockerd did not become ready"; tail -n 40 /var/log/dockerd.log || true; exit 1
fi
log "dockerd ready"

# 2. Register a one-shot ephemeral runner through the admin API.
RUNNER_NAME="cicd-runner-$(hostname)-$(date +%s)"
log "registering ephemeral runner ${RUNNER_NAME}..."
RESP="$(curl -fsSL -X POST \
  -H "Authorization: token ${RUNNER_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${RUNNER_NAME}\",\"ephemeral\":true}" \
  "${RUNNER_SERVER_URL%/}${RUNNER_REGISTER_PATH}")"

UUID="$(echo "${RESP}" | jq -r '.uuid // empty')"
TOKEN="$(echo "${RESP}" | jq -r '.token // empty')"
if [ -z "${UUID}" ] || [ -z "${TOKEN}" ]; then
  log "runner registration failed: ${RESP}"; exit 1
fi
log "registered uuid=${UUID}"

# 3. Run exactly one job then exit. The server auto-removes the ephemeral
#    runner. one-job loads the token from a resolvable secret URL (file:), not
#    a --token flag.
printf '%s' "${TOKEN}" > /tmp/runner-token
log "running one job (labels: ${RUNNER_LABELS})..."
# No --wait: fetch one task and run it to completion; if another runner already
# claimed it, exit immediately instead of blocking.
#
# Exit-code handling: `one-job` exits non-zero with "no task received" when the
# runner pool was scaled up past the number of queued tasks and another runner
# claimed this one first. That is a race, not a failure — exit 0 so the run
# history stays readable.
set +e
cicd-runner one-job \
  --config /etc/cicd-runner/config.yaml \
  --url "${RUNNER_SERVER_URL}" \
  --uuid "${UUID}" \
  --token-url "file:/tmp/runner-token" \
  --label "${RUNNER_LABELS}" 2>&1 | tee /tmp/runner-output.log
RUNNER_RC=${PIPESTATUS[0]}
set -e

if [ "${RUNNER_RC}" -ne 0 ] && grep -q "no task received" /tmp/runner-output.log; then
  log "no task received (another runner claimed it first); exiting cleanly"
  exit 0
fi
exit "${RUNNER_RC}"
