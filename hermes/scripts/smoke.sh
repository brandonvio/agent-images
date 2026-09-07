#!/usr/bin/env bash
# hermes smoke test.
#
# Note: this image puts the Hermes venv first on PATH, so `python3` here is the
# venv's interpreter, not agent-base's. agent-base's
# `command -v python3 = /usr/local/bin/python3` assertion is correct there and
# wrong here; hermes gets its own.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok: $*"; }

# --- the venv runs on the interpreter it was built for ---------------------
got="$(/opt/hermes/.venv/bin/python -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
[ "$got" = "$EXPECT_HERMES_PYTHON" ] \
  || fail "hermes venv python $got != pinned $EXPECT_HERMES_PYTHON"
ok "hermes venv interpreter is $got"

[ "$(command -v python3)" = /opt/hermes/.venv/bin/python3 ] \
  || fail "python3 resolves to $(command -v python3), expected the hermes venv"
ok "PATH resolves python3 to the hermes venv"

# A bare --version passes on a venv whose site-packages are unloadable, so the
# imports are the assertion that matters: these carry 3.13-ABI extension
# modules and would fail here, not at build time, on a mismatched interpreter.
/opt/hermes/.venv/bin/python - <<'PY'
import openai
import openai.lib._parsing._responses as parsing
print("openai", openai.__version__)
src = open(parsing.__file__).read()
assert "for output in (response.output or []):" in src, "codex null-output patch missing"
PY
ok "openai SDK imports and carries the applied patch"

/opt/hermes/.venv/bin/python -c 'import hermes_cli' 2>/dev/null \
  || /opt/hermes/.venv/bin/hermes --version >/dev/null \
  || fail "the hermes CLI does not run"
ok "hermes CLI runs"

# --- inherited agent-base contract -----------------------------------------
[ "$(command -v node)" = /usr/local/bin/node ] \
  || fail "node resolves to $(command -v node), expected /usr/local/bin/node"
node -e 'process.exit(process.execPath.startsWith("/opt/nvm/") ? 0 : 1)'
command -v gosu >/dev/null || fail "gosu is missing; the entrypoint execs it"
command -v uv >/dev/null && command -v uvx >/dev/null
uv --version | grep -qF "$EXPECT_UV" || fail "uv is not the pinned agent-base build"
ok "inherited node, uv and gosu are intact"

# The workspace bundle and the hermes entrypoint must both be in place.
[ -f /opt/hermes-workspace/server-entry.js ] || fail "workspace bundle missing"
[ -x /usr/local/bin/hermes-dev-entrypoint ] || fail "entrypoint missing"
ok "workspace bundle and entrypoint are present"

# --- no stale global npm prefix left behind --------------------------------
grep -RIl --exclude-dir=/proc '/usr/local/lib/node_modules' /usr/local/bin 2>/dev/null \
  && fail "a hardcoded global npm prefix survived the nvm move"
[ -d "$(npm root -g)" ] || fail "npm root -g does not resolve"
ok "npm prefix is derived, not hardcoded"

echo "hermes smoke: PASS"
