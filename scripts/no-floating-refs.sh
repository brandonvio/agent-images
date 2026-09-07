#!/usr/bin/env bash
#
# no-floating-refs — every externally fetched artifact in this repo is pinned by
# exact version, and where the fetch is a raw download, verified by sha256. This
# check exists so that discipline outlives whoever remembers it.
#
# Scans the tracked Dockerfiles, bake files, pin files and workflows for:
#   * `latest` / `stable` as a version
#   * `stable.txt`-style "give me whatever is current" endpoints
#   * `--depth 1` clones with no commit SHA on the line
#   * fetches from a `/HEAD/` path
#   * FROM lines that resolve to a tag rather than a digest
#
# Four documented exceptions are allowlisted, and nothing else:
#   1-2. the local-convenience AGENT_BASE_IMAGE / BASE_IMAGE defaults, which CI
#        always overrides with a resolved digest
#   3.   the `:latest` tag this repo itself publishes
#   4.   the upstream hermes-workspace ref, whose `:latest` tag is decoration on
#        an `@sha256:` digest that is what actually resolves
set -uo pipefail

status=0
files="$(git ls-files -- '*Dockerfile' '*docker-bake.hcl' '*pins.json' '.github/workflows/*' | sort)"

report() {
  echo "  $1"
  status=1
}

for file in $files; do
  [ -f "$file" ] || continue
  lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    loc="${file}:${lineno}"

    # Comments are prose, not build instructions.
    case "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')" in
      '#'*) continue ;;
    esac

    # A digest pins the reference; a tag alongside it is readability only.
    has_digest=0
    case "$line" in *"@sha256:"*) has_digest=1 ;; esac

    # Allowlist 1-3: the local-convenience base default, and the tags this repo
    # itself publishes. `brandonvio/agent-base:latest` is the documented default
    # for a bare `make build`; CI always overrides it with a resolved digest.
    case "$line" in
      *brandonvio/agent-base:latest*|*AGENT_BASE_IMAGE*|*BASE_IMAGE*|*IMAGE_REF*|*'${IMAGE}'*|*'$IMAGE:'*|*buildcache*)
        continue ;;
    esac

    if [ "$has_digest" -eq 0 ]; then
      case "$line" in
        *:latest*|*@latest*|*'"latest"'*)
          report "$loc: floating 'latest' — $line" ; continue ;;
      esac
      case "$line" in
        *'"stable"'*|*=stable*|*:stable*)
          report "$loc: floating 'stable' — $line" ; continue ;;
      esac
    fi

    case "$line" in
      *stable.txt*)
        report "$loc: resolves a version at build time — $line" ; continue ;;
    esac

    case "$line" in
      */HEAD/*)
        report "$loc: fetch from a /HEAD/ path — $line" ; continue ;;
    esac

    # `git clone --depth 1 <url>` takes whatever HEAD happens to be. Fetching a
    # named ref shallowly (`git fetch --depth 1 origin <sha>`) is the pinned
    # form and is what this repo uses.
    case "$line" in
      *'--depth 1'*)
        case "$line" in
          *'git clone'*|*'git -C '*' clone'*)
            report "$loc: shallow clone of a moving HEAD — $line" ;;
          *'fetch'*'origin '*) ;;
          *) report "$loc: shallow fetch with no ref — $line" ;;
        esac
        continue ;;
    esac

    # FROM must resolve by digest, unless it is substituting a build ARG (whose
    # own default is checked on its own line) or naming a previous stage.
    case "$line" in
      FROM\ *|from\ *)
        case "$line" in
          *'${'*|*' AS '*|*' as '*) ;;
        esac
        if [ "$has_digest" -eq 0 ]; then
          case "$line" in
            *'${'*) ;;
            *) report "$loc: FROM without a digest — $line" ;;
          esac
        fi
        ;;
    esac
  done < "$file"
done

if [ "$status" -eq 0 ]; then
  echo "ok: no floating refs"
else
  echo "FAIL: floating refs above"
fi
exit "$status"
