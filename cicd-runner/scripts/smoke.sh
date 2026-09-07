#!/usr/bin/env bash
# cicd-runner smoke test.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok: $*"; }

cicd-runner --version | grep -qF "$EXPECT_RUNNER" \
  || fail "cicd-runner --version is not the pinned $EXPECT_RUNNER"
ok "cicd-runner is the pinned version"

docker --version >/dev/null || fail "docker client missing"
command -v dockerd >/dev/null || fail "dockerd missing"
ok "docker client and daemon binaries are present"

for tool in curl jq git bash node; do
  command -v "$tool" >/dev/null || fail "$tool is missing"
done
ok "job-side tooling is present"

[ -f /etc/cicd-runner/config.yaml ] || fail "runner config missing"
[ -x /usr/local/bin/entrypoint.sh ] || fail "entrypoint missing"
ok "config and entrypoint are in place"

# The entrypoint must refuse to start without its required connection settings
# rather than silently registering nothing.
if RUNNER_SERVER_URL= RUNNER_API_TOKEN= /usr/local/bin/entrypoint.sh >/dev/null 2>&1; then
  fail "entrypoint did not reject a missing RUNNER_SERVER_URL"
fi
ok "entrypoint rejects an incomplete configuration"

echo "cicd-runner smoke: PASS"
