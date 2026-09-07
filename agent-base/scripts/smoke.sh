#!/usr/bin/env bash
# agent-base smoke test.
#
# Run against a published image with:  make smoke IMAGE_REF=<repo>@<digest>
# The Makefile pipes this file into the container and passes the EXPECT_*
# values out of pins.json / package.json, so the assertions cannot rot against
# constants baked in here.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok: $*"; }

# --- runtime identity, not version strings --------------------------------
[ "$(command -v python3)" = /usr/local/bin/python3 ] \
  || fail "python3 resolves to $(command -v python3), expected /usr/local/bin/python3"
[ "$(command -v node)" = /usr/local/bin/node ] \
  || fail "node resolves to $(command -v node), expected /usr/local/bin/node"
ok "interpreters resolve through /usr/local/bin"

python3 -c 'import sys; assert sys.base_prefix.startswith("/opt/python"), sys.base_prefix'
ok "python base_prefix is under /opt/python"

node -e 'process.exit(process.execPath.startsWith("/opt/nvm/") ? 0 : 1)' \
  || fail "node execPath is not under /opt/nvm/"
ok "node execPath is under /opt/nvm"

# --- versions match the committed pins ------------------------------------
got="$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
[ "$got" = "$EXPECT_PYTHON" ] || fail "python $got != pinned $EXPECT_PYTHON"
got="$(node -e 'process.stdout.write(process.versions.node)')"
[ "$got" = "$EXPECT_NODE" ] || fail "node $got != pinned $EXPECT_NODE"
got="$(uv --version | awk '{print $2}')"
[ "$got" = "$EXPECT_UV" ] || fail "uv $got != pinned $EXPECT_UV"
got="$(go version | awk '{print $3}')"
[ "$got" = "go${EXPECT_GO}" ] || fail "go $got != pinned go${EXPECT_GO}"
got="$(rustc --version | awk '{print $2}')"
[ "$got" = "$EXPECT_RUST" ] || fail "rustc $got != pinned $EXPECT_RUST"
got="$(kubectl version --client=true -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)["clientVersion"]["gitVersion"])')"
[ "$got" = "$EXPECT_KUBECTL" ] || fail "kubectl $got != pinned $EXPECT_KUBECTL"
ok "toolchain versions match pins.json"

claude --version | grep -qF "$EXPECT_CLAUDE" || fail "claude --version lacks $EXPECT_CLAUDE"
codex --version  | grep -qF "$EXPECT_CODEX"  || fail "codex --version lacks $EXPECT_CODEX"
ok "agent CLI versions match package.json"

# --- the rest of the contract ---------------------------------------------
uvx --version >/dev/null
python3 -m pip --version >/dev/null
command -v gosu >/dev/null || fail "gosu is missing; child entrypoints exec it to drop privileges"
command -v argocd >/dev/null
command -v gh >/dev/null
command -v git-lfs >/dev/null
command -v jq >/dev/null
command -v yq >/dev/null
command -v chromium >/dev/null
ok "shipped CLIs are present"

# nvm stays available as an escape hatch, but nothing depends on it at runtime.
[ -r /opt/nvm/nvm.sh ] || fail "/opt/nvm/nvm.sh missing"
/bin/sh -c 'node -v >/dev/null && npm -v >/dev/null' \
  || fail "node/npm are not usable from a non-login /bin/sh"
ok "node works from a non-login shell without sourcing nvm"

# --- shared prefixes must be usable by every account, not just root -------
su -s /bin/bash workspace -c '
  set -e
  test "$(command -v python3)" = /usr/local/bin/python3
  python3 -c "import sys; assert sys.base_prefix.startswith(\"/opt/python\")"
  node -e "process.exit(0)"
  uv --version >/dev/null
' || fail "the workspace account cannot use the shared /opt runtimes"
su -s /bin/bash openclaw -c 'node -v >/dev/null && python3 -V >/dev/null' \
  || fail "the openclaw account cannot use the shared /opt runtimes"
ok "non-root accounts can use /opt/python and /opt/nvm"

# --- accounts, sudo, sshd, shell ------------------------------------------
getent passwd root         | grep -q '/usr/bin/zsh'
getent passwd hermes-agent | grep -q '/usr/bin/zsh'
sudo -l -U hermes-agent | grep -q 'NOPASSWD: ALL'
agent-start-sshd
sshd -T >/dev/null
ok "accounts, sudo and sshd are configured"

zsh -ic 'test "$ZSH_THEME" = maran \
  && test -f "$ZSH/themes/maran.zsh-theme" \
  && test -d "$ZSH/custom/plugins/zsh-autosuggestions" \
  && test -d "$ZSH/custom/plugins/zsh-syntax-highlighting" \
  && test -d "$ZSH/custom/plugins/zsh-completions"'
ok "zsh environment is configured"

echo "agent-base smoke: PASS"
