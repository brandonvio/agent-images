#!/usr/bin/env bash
#
# Point OpenClaw's default agent at the OpenAI API, then hand off to the image's
# own entrypoint unchanged.
set -euo pipefail

: "${OPENCLAW_HOME:=/home/openclaw/.openclaw}"
: "${OPENCLAW_STATE_DIR:=$OPENCLAW_HOME}"
: "${HARNESS_MODEL:=openai/gpt-5.6-luna}"
: "${HARNESS_RUNTIME:=openclaw}"

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "openclaw-harness: OPENAI_API_KEY is not set." >&2
  echo "openclaw-harness: pass it at run time (--env-file .env); it is deliberately not baked into this image." >&2
  exit 1
fi

mkdir -p "$OPENCLAW_STATE_DIR"
chown -R openclaw:openclaw "$OPENCLAW_STATE_DIR" 2>/dev/null || true

# `config get` is read-only; `config set` rewrites the file and rolls its single
# backup even when the value is unchanged. So each key is written only when it
# is absent or differs — a restart with the same settings touches nothing, and a
# model chosen later with `openclaw models set` survives.
seed() {
  local path="$1" want="$2" have
  have="$(gosu openclaw openclaw config get "$path" 2>/dev/null || true)"
  if [[ "$have" == "$want" ]]; then
    echo "openclaw-harness: ${path} already ${want}"
    return 0
  fi
  if [[ -n "$have" ]]; then
    echo "openclaw-harness: ${path} is ${have}, leaving it alone"
    return 0
  fi
  gosu openclaw openclaw config set "$path" "$want" >/dev/null
  echo "openclaw-harness: set ${path} = ${want}"
}

seed agents.defaults.model.primary "$HARNESS_MODEL"
seed models.providers.openai.agentRuntime.id "$HARNESS_RUNTIME"

exec /entrypoint.sh "$@"
