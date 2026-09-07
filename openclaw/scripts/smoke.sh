#!/usr/bin/env bash
# openclaw smoke test.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok: $*"; }

openclaw --version | grep -qF "$EXPECT_OPENCLAW" \
  || fail "openclaw --version is not the pinned $EXPECT_OPENCLAW"
ok "openclaw is the pinned version"

# The gateway drops privileges with gosu; without it the entrypoint dies on the
# first run rather than at build time.
command -v gosu >/dev/null || fail "gosu is missing; the entrypoint execs it"
su -s /bin/bash openclaw -c 'openclaw --version >/dev/null' \
  || fail "the openclaw account cannot run openclaw"
ok "the openclaw account can run the gateway binary"

# --- inherited agent-base contract -----------------------------------------
[ "$(command -v python3)" = /usr/local/bin/python3 ] \
  || fail "python3 resolves to $(command -v python3)"
[ "$(command -v node)" = /usr/local/bin/node ] \
  || fail "node resolves to $(command -v node)"
python3 -c 'import sys; assert sys.base_prefix.startswith("/opt/python"), sys.base_prefix'
node -e 'process.exit(process.execPath.startsWith("/opt/nvm/") ? 0 : 1)'
command -v kubectl >/dev/null && command -v go >/dev/null && command -v rustc >/dev/null
ok "inherited runtimes and CLIs are intact"

[ -x /entrypoint.sh ] || fail "entrypoint missing"
[ -d /home/openclaw/.openclaw ] || fail "state directory missing"
agent-start-sshd
sshd -T >/dev/null
ok "entrypoint, state directory and sshd are configured"

echo "openclaw smoke: PASS"
