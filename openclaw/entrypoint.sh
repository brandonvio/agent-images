#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/home/openclaw}"
export OPENCLAW_HOME="${OPENCLAW_HOME:-/home/openclaw/.openclaw}"
export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-$OPENCLAW_HOME}"
export AGENT_SSH_HOST_KEYS_DIR="${AGENT_SSH_HOST_KEYS_DIR:-/home/openclaw/ssh-host-keys}"
export AGENT_SSH_AUTHORIZED_USERS="${AGENT_SSH_AUTHORIZED_USERS:-openclaw}"

if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  if [[ "${OPENCLAW_ALLOW_DEFAULT_GATEWAY_TOKEN:-0}" == "1" ]]; then
    export OPENCLAW_GATEWAY_TOKEN="local-dev"
  else
    echo "OPENCLAW_GATEWAY_TOKEN is required; provide it in the environment." >&2
    exit 1
  fi
fi

mkdir -p "$HOME" "$OPENCLAW_HOME" "$OPENCLAW_STATE_DIR" "$AGENT_SSH_HOST_KEYS_DIR"
chown -R openclaw:openclaw "$HOME" "$OPENCLAW_HOME" "$OPENCLAW_STATE_DIR" "$AGENT_SSH_HOST_KEYS_DIR" 2>/dev/null || true
chmod -R u+rwX,go-rwX "$HOME" "$OPENCLAW_HOME" "$OPENCLAW_STATE_DIR" "$AGENT_SSH_HOST_KEYS_DIR" 2>/dev/null || true

agent-start-sshd

case "${1:-gateway}" in
  gateway)
    shift || true
    ;;
  bash | sh | zsh | fish | sleep | tail | openclaw | node | npm | codex | claude | python | python3)
    exec "$@"
    ;;
  *)
    exec "$@"
    ;;
esac

# Binding off the loopback interface requires a Control UI origin policy. The
# dashboard is already protected by the shared gateway token, so device pairing
# is disabled for this single-user deployment.
gosu openclaw openclaw config set gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback true
gosu openclaw openclaw config set gateway.controlUi.dangerouslyDisableDeviceAuth true
gosu openclaw openclaw config set gateway.mode local
gosu openclaw openclaw config set gateway.bind lan
gosu openclaw openclaw config set gateway.auth.mode token
gosu openclaw openclaw config set gateway.auth.token "$OPENCLAW_GATEWAY_TOKEN"
gosu openclaw openclaw config set gateway.http.endpoints.chatCompletions.enabled true --strict-json
gosu openclaw openclaw config set gateway.http.endpoints.responses.enabled true --strict-json
exec gosu openclaw openclaw gateway \
  --auth token \
  --token "$OPENCLAW_GATEWAY_TOKEN" \
  --bind lan \
  --port 18789 \
  "$@"
