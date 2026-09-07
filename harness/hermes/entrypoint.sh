#!/usr/bin/env bash
#
# Point Hermes's default agent at the OpenAI API, then hand off to the image's
# own entrypoint unchanged.
set -euo pipefail

: "${HERMES_HOME:=/home/workspace/.hermes}"
: "${HARNESS_MODEL:=gpt-5.6-luna}"
: "${HARNESS_PROVIDER:=openai-api}"
: "${HARNESS_BASE_URL:=https://api.openai.com/v1}"

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "hermes-harness: OPENAI_API_KEY is not set." >&2
  echo "hermes-harness: pass it at run time (--env-file .env); it is deliberately not baked into this image." >&2
  exit 1
fi

# Two paths read the model, and they disagree on purpose. At startup Hermes
# prefers HERMES_MODEL; from the first turn onward the per-turn sync prefers
# config.yaml, so that a model change made in the dashboard or with `hermes
# model` reaches an open chat. Set both, or the agent boots on this model and
# then silently reverts to whatever config.yaml holds.
export HERMES_MODEL="${HARNESS_MODEL}"
export HERMES_INFERENCE_MODEL="${HARNESS_MODEL}"
export HERMES_INFERENCE_PROVIDER="${HARNESS_PROVIDER}"

# Seeded once, on a data directory that has no config yet. Never rewritten:
# this file is the user's after first boot — changing the model in the
# dashboard or with `hermes model` has to survive a container restart.
config="${HERMES_HOME}/config.yaml"
if [[ ! -e "$config" ]]; then
  mkdir -p "$HERMES_HOME"
  cat > "$config" <<YAML
model:
  default: ${HARNESS_MODEL}
  provider: ${HARNESS_PROVIDER}
  base_url: ${HARNESS_BASE_URL}
providers: {}
fallback_providers: []
toolsets:
- hermes-cli
YAML
  chmod a+rw "$config" 2>/dev/null || true
  echo "hermes-harness: seeded ${config} with ${HARNESS_PROVIDER}/${HARNESS_MODEL}"
else
  echo "hermes-harness: ${config} exists, leaving it alone"
fi

exec /usr/local/bin/hermes-dev-entrypoint "$@"
