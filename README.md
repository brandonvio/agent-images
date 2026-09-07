# agent-images

Five general-purpose container images, built from committed pins and published
to Docker Hub under [`brandonvio`](https://hub.docker.com/u/brandonvio).

| Image | What it is | Platforms |
| --- | --- | --- |
| [`brandonvio/agent-base`](agent-base/) | Ubuntu 24.04 development base: one pinned Python, one pinned Node, Go, Rust, the Claude Code and Codex CLIs, sshd, zsh | `amd64`, `arm64` |
| [`brandonvio/hermes`](hermes/) | The Hermes agent and its web workspace, layered onto `agent-base` | `amd64`, `arm64` |
| [`brandonvio/openclaw`](openclaw/) | The OpenClaw gateway, layered onto `agent-base` | `amd64`, `arm64` |
| [`brandonvio/cicd-runner`](cicd-runner/) | Ephemeral one-shot CI job runner with an in-container dockerd | `amd64` |
| [`brandonvio/gpu-enabled`](gpu-enabled/) | CUDA + ffmpeg with `torch`, `torchaudio`, `whisperx` and `pyannote-audio` pre-installed (cuDNN from the torch wheels) | `amd64` |

```bash
docker pull brandonvio/agent-base:latest
docker run --rm -it brandonvio/agent-base:latest
```

## What "pinned" means here

No build instruction in this repo contains `latest`, `stable`, a bare major
version, an unpinned clone, or an untagged base image. Concretely:

| Artifact | Pin form |
| --- | --- |
| Base images | `name:tag@sha256:<digest>` — the tag is readability, the digest is what resolves |
| Node | exact `X.Y.Z` plus a per-architecture tarball sha256 |
| Python | exact `X.Y.Z` installed by `uv` |
| `uv`, Go, `kubectl`, `argocd`, the CI runner binary | exact version plus a per-architecture sha256 |
| Rust | exact toolchain version |
| `nvm`, oh-my-zsh and its plugins | exact commit SHA per checkout |
| The agent CLIs | `agent-base/package.json` + a committed `package-lock.json`, installed with `npm ci` |
| `gpu-enabled`'s Python set | `pyproject.toml` + a committed `uv.lock` + `.python-version`, installed with `uv sync --frozen` |
| The Hermes and OpenClaw releases | exact version in the image's own pin file |

Two files carry this, and neither duplicates the other:

- **`<image>/pins.json`** holds only what has no native lockfile — raw downloads
  and base-image digests. It is the lockfile for `curl`. It carries the one
  thing no existing format holds: a sha256 per *(artifact, architecture)*.
- **`<image>/docker-bake.hcl`** reads that file and turns it into build
  arguments, so a pin bump is a one-file diff and the same command produces the
  same bytes locally and in CI.

`pins.json` splits into two sections, and the split is structural rather than a
comment. `managed` is what the nightly refresh rewrites — the current best
version of each upstream artifact. `manual` is what a person bumps
deliberately: the Hermes release, the OpenClaw package version, the upstream
image refs. "May the refresher touch this?" is answerable by position in the
file.

Because everything resolves from the tree, a build is a pure function of the
commit: rebuilding an old commit reproduces that commit's image, and
`git log -p agent-base/pins.json` is a complete history of what every published
image contained.

## Building locally

Every image builds the same way, from its own directory:

```bash
cd agent-base
make print       # show the resolved build arguments
make build       # build from the committed pins
make smoke       # assert the built image matches those pins
```

`make build` is a thin wrapper around `docker buildx bake`. `buildx bake` has
no way to read a file itself, so the Makefile hands `pins.json` to it through
the environment; that is the only place the pin files are read.

`hermes` and `openclaw` build on top of `agent-base`. Their default is the
published image, which is a convenience for a bare `make build`; point them at
a local one while iterating:

```bash
cd agent-base && make build                       # -> brandonvio/agent-base:local
cd ../hermes  && make build AGENT_BASE_IMAGE=brandonvio/agent-base:local
```

On Apple Silicon, add `PLATFORM=linux/arm64` to build natively rather than
under emulation. `cicd-runner` and `gpu-enabled` are `amd64` only.

## Checks

```bash
python3 scripts/validate-pins.py     # shape of every pins.json
python3 scripts/validate-pins.py --verify-hashes   # and check each sha256 against the download
bash scripts/no-floating-refs.sh     # nothing floating slipped into a build instruction
bash scripts/provenance-scan.sh      # the repo reads as a standalone product
```

`validate-pins` exists because the pin files are written by an agent rather than
by a script with fixed control flow: it checks that no key was silently
dropped, that every version is non-empty and not a floating word, that every raw
download carries one 64-hex sha256 per supported architecture, and that every
base-image reference carries an `@sha256:`. A malformed pin file fails there,
not forty minutes into a build and never after publish.

## What these images assume about where they run

Nothing. `agent-base` ships `kubectl` and `argocd` as general-purpose CLIs
alongside `gh`, `git`, `git-lfs`, `jq` and `yq` — point them at whatever you
like. No image in this repo assumes it is *running under* any particular
orchestrator, and `scripts/provenance-scan.sh` keeps it that way.

## Security posture

These images are development and agent environments, and their layout is
disclosed deliberately:

- `agent-base` enables `PermitRootLogin yes` with `PasswordAuthentication no`,
  and grants NOPASSWD sudo to `root`, `hermes`, `workspace`, `openclaw` and
  `hermes-agent`. Public-key material is supplied at runtime; no keys or
  credentials are baked in.
- `cicd-runner` runs a privileged dockerd inside the container and executes
  arbitrary job code against it. Run it under whatever VM-grade isolation your
  platform provides.

## License

MIT. The images bundle third-party software under its own licenses.
