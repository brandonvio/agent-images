#!/usr/bin/env bash
#
# provenance-scan — this repo publishes general-purpose images judged on what
# they provide, not a mirror of anyone's infrastructure. Three rules are
# enforced here rather than left to discipline:
#
#   origin       no identifier that only means something inside some other
#                repository or private network
#   k8s-runtime  images may carry Kubernetes *clients* (kubectl, argocd) but
#                must never describe themselves as Kubernetes *workloads*
#   homebrew     Homebrew is excluded outright — the tool, the paths, the prose
#   vendor       the CI runner image is presented as a generic one-shot runner,
#                not as one vendor's product
#
# Scope is `git ls-files`, so anything gitignored is out of scope by
# construction. Commit messages in the range are scanned too: the rule binds
# them, and a tree-only grep would leave the strongest-stated part of it the
# least enforced.
#
# Note on what is deliberately absent: kubectl, argocd, kubernetes and
# kubeconfig are NOT patterns. Those tools ship in agent-base and the repo is
# expected to name them. The k8s-runtime group bans the vocabulary of *being
# deployed by* Kubernetes, not the vocabulary of *talking to* it. `cluster` is
# a manual review item rather than a regex: "point kubectl at your cluster" is
# fine and "the infra cluster's exposed port" is not, and the word alone cannot
# tell them apart.
set -uo pipefail

status=0

# Two documented allowlisted hits, both third-party artifacts this repo actually
# downloads. Everything else — names, env vars, paths, labels, prose — is
# expected to be vendor-neutral, and the groups below are what keeps it that way.
allowlisted_hit() {
  local file="$1" line="$2"
  case "$file" in
    hermes/Dockerfile | hermes/pins.json)
      [[ "$line" == *"ghcr.io/outsourc-e/hermes-workspace"* ]] && return 0
      ;;
    cicd-runner/pins.json)
      # The runner binary has to be fetched from somewhere. Its download URL is
      # the single place the upstream project is named; the image, the binary on
      # disk, its config path, its env vars and its docs are all neutral.
      [[ "$line" == *"code.forgejo.org"* ]] && return 0
      ;;
    scripts/provenance-scan.sh)
      # This file names the patterns it enforces.
      return 0
      ;;
  esac
  return 1
}

scan_group() {
  local name="$1" pattern="$2"
  local hits=0 file line

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # Skip binary files.
    grep -Iq . "$file" 2>/dev/null || continue
    while IFS= read -r line; do
      if allowlisted_hit "$file" "$line"; then
        continue
      fi
      echo "  ${file}: ${line}"
      hits=$((hits + 1))
    done < <(grep -inE "$pattern" "$file" 2>/dev/null)
  done < <(git ls-files)

  if [ "$hits" -gt 0 ]; then
    echo "FAIL [$name]: $hits hit(s) above"
    status=1
  else
    echo "ok [$name]: clean"
  fi
}

ORIGIN='lvrgd|nvda:?[0-9]*|mediax|infra/images|release-state|tailscale|30500|outsourc'
K8S_RUNTIME='kata|keda|nodeport|\bpvc\b|runtimeclass|scaledjob|\bpod\b'
HOMEBREW='homebrew|linuxbrew|\bbrew\b'
VENDOR='forgejo'

echo "== tree =="
scan_group origin      "$ORIGIN"
scan_group k8s-runtime "$K8S_RUNTIME"
scan_group homebrew    "$HOMEBREW"
scan_group vendor      "$VENDOR"

# --- commit messages -------------------------------------------------------
# RANGE is set by CI to the push/PR range; locally it defaults to every commit.
RANGE="${RANGE:-}"
echo "== commit messages =="
if [ -n "$RANGE" ]; then
  log_body="$(git log --format=%B "$RANGE" 2>/dev/null || true)"
else
  log_body="$(git log --format=%B 2>/dev/null || true)"
fi

if [ -z "$log_body" ]; then
  echo "ok: no commit messages in range"
else
  for spec in "origin:$ORIGIN" "k8s-runtime:$K8S_RUNTIME" "homebrew:$HOMEBREW" "vendor:$VENDOR"; do
    gname="${spec%%:*}"; gpat="${spec#*:}"
    if hits="$(printf '%s\n' "$log_body" | grep -inE "$gpat")"; then
      echo "FAIL [$gname] in commit messages:"
      printf '%s\n' "$hits" | sed 's/^/  /'
      status=1
    else
      echo "ok [$gname]: clean"
    fi
  done
fi

exit "$status"
