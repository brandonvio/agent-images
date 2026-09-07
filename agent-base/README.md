# agent-base

`brandonvio/agent-base` — an Ubuntu 24.04 development image for coding agents
and the people who supervise them. Platforms: `linux/amd64`, `linux/arm64`.

```bash
docker pull brandonvio/agent-base:latest
docker run --rm -it brandonvio/agent-base:latest
```

## The runtime contract

Exactly one Python and exactly one Node. There is no second, prior, or
"compatibility" major of anything, and no second interpreter to shadow the
first on `PATH`. If you need a different one, `uv` and `nvm` are both here and
that is a one-line runtime operation — `uv python install 3.13`,
`nvm install 22` — rather than baked image weight.

```
Node — nvm, shared prefix
  NVM_DIR=/opt/nvm                              nvm itself, at a pinned commit
  /opt/nvm/versions/node/v<NODE_VERSION>/       the one installed Node
  /usr/local/bin/{node,npm,npx}                 -> that version's bin/*
  <that version>/lib/node_modules               global npm prefix

Python — uv-managed CPython, shared prefix
  UV_PYTHON_INSTALL_DIR=/opt/python             the one installed CPython
  /usr/local/bin/{python,python3}               -> uv-managed CPython
  /usr/local/bin/{uv,uvx}                       pinned uv release

Agent CLIs
  /opt/agent-cli/node_modules                   installed with `npm ci`
  /usr/local/bin/{claude,codex,playwright}      -> that tree's .bin entries

PATH  /usr/local/bin first
```

Both prefixes are deliberately outside `$HOME`. `uv` and `nvm` default to
`~/.local/share/uv/python` and `~/.nvm`, which under Docker means `/root/…` —
unreadable to the other accounts this image creates. `/opt/python` and
`/opt/nvm` are world-readable so every account can use them, and the smoke test
asserts that as a non-root user rather than as root.

**`nvm` is an installer and an escape hatch, not the access path.** It is a
shell function, so any `RUN` that calls it must source `$NVM_DIR/nvm.sh` first —
and nothing at runtime may depend on that having happened. sshd sessions,
`docker exec` and cron all start without it. The `/usr/local/bin` symlinks are
the contract.

**Package management is `uv`** (`uv venv`, `uv pip`, `uv add`, `uv run`).
`python3 -m pip` exists for tools that shell out to it, but no global
`pip`/`pip3` shim is created — a bare system-level `pip install` is not a
workflow this image endorses, and a shim would only make it look supported.

Ubuntu's own `python3` remains present as a transitive dependency of apt
tooling, whose absolute `#!/usr/bin/python3` shebangs are unaffected by `PATH`
order. It is off-contract and undocumented. Note the consequence: anything that
shells out to `python3` inside this image gets the uv-managed CPython, not
Ubuntu's.

## What's installed

Read the exact versions out of `pins.json`, or off the built image:

```bash
docker inspect --format '{{json .Config.Labels}}' brandonvio/agent-base:latest | jq
```

**Languages and package managers** — CPython (uv-managed), Node (nvm layout),
Go, Rust via rustup, `uv`/`uvx`, `npm`/`npx`.

**Agent CLIs** — Claude Code (`claude`), Codex (`codex`), Playwright with a
Chromium browser at `/ms-playwright` and `chromium`/`chromium-browser`/
`google-chrome` symlinks.

**Kubernetes and GitOps clients** — `kubectl` and `argocd`, both pinned by
version and per-architecture sha256, with the `kubectl` oh-my-zsh plugin, shell
completion and `alias k='kubectl'`. These are tools the image ships; nothing in
this image assumes it is running under an orchestrator.

**Developer CLIs** — `gh`, `git`, `git-lfs`, `jq`, `yq`, `ripgrep`, `fd`, `bat`,
`fzf`, `direnv`, `tmux`, `vim`, `nano`, `shellcheck`, `shfmt`, `sqlite3`,
`htop`, `strace`, `gdb`, `tcpdump`, `socat`, `rsync`, and the usual network
tools.

**Build toolchain** — `build-essential`, `clang`, `cmake`, `autoconf`,
`automake`, `bison`, `gettext`, `pkg-config` and the `lib*-dev` set. Nothing in
this build needs them any more; they are kept because they are genuinely useful
in a development image.

**`gosu`** — no build step uses it, but the entrypoints of `hermes` and
`openclaw` exec it to drop privileges at runtime. Removing it would build three
images cleanly and kill two of them on first run. The smoke test asserts it.

## Accounts and shells

| Account | UID | Home | Shell |
| --- | --- | --- | --- |
| `root` | 0 | `/root` | zsh |
| `hermes` | 10000 | `/opt/data` | zsh |
| `workspace` | 10010 | `/home/workspace` | zsh |
| `openclaw` | 10020 | `/home/openclaw` | zsh |
| `hermes-agent` | 10030 | `/opt/data/home` | zsh |

All five have NOPASSWD sudo. oh-my-zsh lives at `/opt/oh-my-zsh` with a shared
`/etc/zsh/zshrc`, the `maran` theme, and the autosuggestions,
syntax-highlighting and completions plugins.

## SSH

`agent-start-sshd` (on `PATH` at `/usr/local/sbin`) prepares host keys and
starts sshd:

- Host keys persist in `AGENT_SSH_HOST_KEYS_DIR`
  (default `/var/lib/agent-base/ssh-host-keys`); mount a volume there to keep a
  stable host identity across restarts.
- Authorized keys are read from `AGENT_SSH_AUTHORIZED_KEYS_PATH`
  (default `/tmp/ssh-keys/authorized_keys`) and installed for each account in
  `AGENT_SSH_AUTHORIZED_USERS` (default `root hermes-agent`).
- Set `AGENT_START_SSHD=0` to skip it entirely.

The sshd config permits root login with public keys and disables password and
keyboard-interactive authentication.

## Writable paths

`/workspace` (the working directory), `/opt/data`, `/home/workspace`,
`/home/openclaw` and `/ms-playwright` are world-writable so that any of the
accounts above can use them. Mount volumes at whichever of these you want to
persist.

## Building

```bash
make print       # resolved build arguments
make build       # -> brandonvio/agent-base:local
make smoke       # assert the image matches pins.json
make shell
```

Add `PLATFORM=linux/arm64` on Apple Silicon to build natively.

The smoke test checks identity, not version strings: a bare `python3 --version`
proves nothing about *which* interpreter answered, so it asserts the resolved
path and `sys.base_prefix`, asserts `process.execPath` is under `/opt/nvm`, runs
the interpreter checks as a non-root account, and compares every version against
`pins.json` rather than against a constant that would rot.

See [the repository README](../README.md) for how pinning works across all five
images.
