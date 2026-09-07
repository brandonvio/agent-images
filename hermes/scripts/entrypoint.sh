#!/usr/bin/env bash
set -euo pipefail

export HERMES_DOCKER_EXEC_AS_ROOT="${HERMES_DOCKER_EXEC_AS_ROOT:-1}"
export HERMES_AGENT_USER="${HERMES_AGENT_USER:-hermes-agent}"

ensure_dir() {
  local path="$1"
  mkdir -p "$path"
  chmod -R a+rwX "$path" 2>/dev/null || true
}

# The agent CLIs are installed from a lockfile under AGENT_CLI_PREFIX rather
# than into a global npm prefix, and the npm prefix itself lives under the
# nvm-managed Node. Both are derived, never hardcoded: a wrong literal here
# would be a silent no-op (see the `-e` guard below) rather than an error.
agent_cli_root() {
  if [[ -n "${AGENT_CLI_PREFIX:-}" && -d "${AGENT_CLI_PREFIX}/node_modules" ]]; then
    printf '%s\n' "${AGENT_CLI_PREFIX}/node_modules"
  fi
}

npm_global_root() {
  command -v npm >/dev/null 2>&1 || return 0
  npm root -g 2>/dev/null || true
}

prepare_agent_install_paths() {
  [[ "$(id -u)" == "0" ]] || return 0
  getent passwd "$HERMES_AGENT_USER" >/dev/null || return 0

  local agent_home
  agent_home="$(getent passwd "$HERMES_AGENT_USER" | cut -d: -f6)"
  [[ -n "$agent_home" ]] || return 0

  install -d -m 775 -o "$HERMES_AGENT_USER" -g agent \
    "$agent_home/.npm" \
    "$agent_home/.cache" \
    "$agent_home/.config" \
    "$agent_home/.local" \
    "$agent_home/.local/bin"

  local cli_root npm_root
  cli_root="$(agent_cli_root)"
  npm_root="$(npm_global_root)"

  # Writable-by-the-agent trees: the CLI install dirs and the agent's own homes.
  local -a deep=()
  [[ -n "$cli_root" ]] && deep+=("$cli_root")
  deep+=("$agent_home" "$HOME" "$HERMES_HOME")

  # Shallow: directories the agent must be able to write *into*, not own outright.
  local -a shallow=(/usr/local/bin /usr/local/share)
  [[ -n "$npm_root" ]] && shallow+=("$npm_root")

  local path
  for path in "${deep[@]}"; do
    if [[ ! -e "$path" ]]; then
      echo "[hermes-entrypoint] warning: expected path missing, skipping: $path" >&2
      continue
    fi
    chown -Rh "$HERMES_AGENT_USER:agent" "$path" 2>/dev/null || true
    chmod -R u+rwX,g+rwX "$path" 2>/dev/null || true
  done

  for path in "${shallow[@]}"; do
    [[ -e "$path" ]] || continue
    chown -h "$HERMES_AGENT_USER:agent" "$path" 2>/dev/null || true
    chmod u+rwX,g+rwX "$path" 2>/dev/null || true
  done

  chmod 755 "$agent_home" 2>/dev/null || true
  chmod 700 "$agent_home/.ssh" 2>/dev/null || true
  chmod 600 "$agent_home/.ssh/authorized_keys" 2>/dev/null || true
}

prepare_hermes_runtime() {
  export HOME="${HOME:-/opt/data/home}"
  export HERMES_HOME="${HERMES_HOME:-/opt/data}"
  ensure_dir "$HOME"
  ensure_dir "$HERMES_HOME"
  prepare_agent_install_paths
}

exec_as_hermes_agent() {
  if [[ "$(id -u)" == "0" ]]; then
    exec gosu "$HERMES_AGENT_USER" "$@"
  fi
  exec "$@"
}

run_as_hermes() {
  prepare_hermes_runtime
  exec_as_hermes_agent /opt/hermes/.venv/bin/hermes "$@"
}

run_hermes_agent_server() {
  prepare_hermes_runtime
  exec_as_hermes_agent bash -lc '
    set -euo pipefail

    /opt/hermes/.venv/bin/hermes dashboard \
      --host "$HERMES_DASHBOARD_HOST" \
      --port "$HERMES_DASHBOARD_PORT" \
      --no-open \
      --insecure \
      --skip-build &
    dashboard_pid=$!

    /opt/hermes/.venv/bin/hermes gateway run --replace --accept-hooks &
    gateway_pid=$!

    wait -n "$dashboard_pid" "$gateway_pid"
    status=$?
    kill "$dashboard_pid" "$gateway_pid" 2>/dev/null || true
    wait 2>/dev/null || true
    exit "$status"
  '
}

run_workspace() {
  export HOME="${HOME:-/root}"
  export HERMES_HOME="${HERMES_HOME:-/home/workspace/.hermes}"
  export NODE_ENV="${NODE_ENV:-production}"
  export PORT="${PORT:-3000}"
  export HOST="${HOST:-0.0.0.0}"
  export HERMES_API_URL="${HERMES_API_URL:-http://127.0.0.1:8642}"
  export HERMES_API_TOKEN="${HERMES_API_TOKEN:-local-dev}"
  export API_SERVER_ENABLED="${API_SERVER_ENABLED:-true}"
  export API_SERVER_HOST="${API_SERVER_HOST:-0.0.0.0}"
  export API_SERVER_PORT="${API_SERVER_PORT:-8642}"
  export API_SERVER_KEY="${API_SERVER_KEY:-$HERMES_API_TOKEN}"
  export API_SERVER_CORS_ORIGINS="${API_SERVER_CORS_ORIGINS:-*}"
  export GATEWAY_ALLOW_ALL_USERS="${GATEWAY_ALLOW_ALL_USERS:-true}"
  export HERMES_DASHBOARD="${HERMES_DASHBOARD:-1}"
  export HERMES_DASHBOARD_HOST="${HERMES_DASHBOARD_HOST:-0.0.0.0}"
  export HERMES_DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-9119}"
  ensure_dir "$HOME"
  ensure_dir "$HERMES_HOME"
  cd /opt/hermes-workspace

  if [[ "${HERMES_START_GATEWAY:-1}" == "1" ]]; then
    /opt/hermes/.venv/bin/hermes gateway run --replace --accept-hooks &
    gateway_pid=$!
  else
    gateway_pid=""
  fi

  if [[ "${HERMES_START_DASHBOARD:-1}" == "1" ]]; then
    /opt/hermes/.venv/bin/hermes dashboard \
      --host "$HERMES_DASHBOARD_HOST" \
      --port "$HERMES_DASHBOARD_PORT" \
      --no-open \
      --insecure \
      --skip-build &
    dashboard_pid=$!

    for _ in {1..20}; do
      curl -fsS "http://127.0.0.1:${HERMES_DASHBOARD_PORT}/" >/dev/null 2>&1 && break
      sleep 0.25
    done
  else
    dashboard_pid=""
  fi

  node --max-old-space-size=2048 server-entry.js &
  workspace_pid=$!

  pids=("$workspace_pid")
  [[ -n "$gateway_pid" ]] && pids+=("$gateway_pid")
  [[ -n "$dashboard_pid" ]] && pids+=("$dashboard_pid")

  wait -n "${pids[@]}"
  status=$?
  kill "${pids[@]}" 2>/dev/null || true
  wait 2>/dev/null || true
  exit "$status"
}

agent-start-sshd

case "${1:-workspace}" in
  workspace | workspace-server)
    shift || true
    run_workspace "$@"
    ;;
  hermes-agent | agent)
    shift || true
    run_as_hermes "$@"
    ;;
  hermes-agent-server | agent-server)
    shift || true
    run_hermes_agent_server
    ;;
  gateway | chat | model | fallback | proxy | lsp | setup | login | logout | auth | status | cron | webhook | kanban | hooks | doctor | dump | debug | backup | checkpoints | import | config | pairing | skills | plugins | curator | memory | tools | computer-use | mcp | sessions | insights | claw | version | update | uninstall | acp | profile | completion | dashboard | logs)
    run_as_hermes "$@"
    ;;
  bash | sh | zsh | fish | sleep | tail)
    exec "$@"
    ;;
  *)
    exec "$@"
    ;;
esac
