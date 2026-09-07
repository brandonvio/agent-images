# hermes

`brandonvio/hermes` — the Hermes agent and its web workspace, layered onto
[`agent-base`](../agent-base/README.md) so the same shell, accounts, sshd and
developer toolchain are available around them. Platforms: `linux/amd64`,
`linux/arm64`.

```bash
docker pull brandonvio/hermes:latest
```

## What's in it

- The Hermes application and its prebuilt virtualenv at `/opt/hermes`, with
  `hermes` on `PATH`.
- The Hermes web workspace bundle at `/opt/hermes-workspace`.
- Everything `agent-base` provides: Python, Node, Go, Rust, the Claude Code and
  Codex CLIs, `kubectl`, `argocd`, `gh`, sshd and zsh.

## Its Python is its own

Hermes ships a prebuilt virtualenv whose compiled extension modules carry a
3.13 ABI tag. This image therefore installs the exact interpreter that venv was
built for — pinned in `pins.json`, installed with the `uv` that `agent-base`
already provides — rather than repointing the venv at `agent-base`'s newer
Python. Doing the latter would be an ABI change wearing a path change's
clothes: it fails at import time, not at build time.

Two consequences worth knowing:

- **`python3` inside this image is the Hermes venv's interpreter**, because the
  venv leads `PATH`. `agent-base`'s `command -v python3 = /usr/local/bin/python3`
  assertion is correct there and wrong here. `agent-base`'s own interpreter is
  still installed and reachable at `/usr/local/bin/python3` by absolute path.
- **Hermes's Python version moves when someone decides it should**, rather than
  as a silent consequence of an `agent-base` refresh. Keep the pin on the minor
  the upstream venv was built for until someone deliberately tests otherwise.

`uv` and `uvx` come from `agent-base`, pinned. They are deliberately *not*
copied out of the upstream Hermes image, which would replace the pinned binary
with an unpinned one for the image that leans on `uv` hardest.

## Running it

```bash
make build AGENT_BASE_IMAGE=brandonvio/agent-base:local   # or omit to use the published base
make smoke
make dev-up          # workspace + gateway + dashboard
make dev-logs
make dev-shell
make dev-down
```

`make dev-up` publishes:

| Port | What |
| --- | --- |
| 3000 | workspace server |
| 8642 | gateway API |
| 9119 | dashboard |
| 2222 | ssh |

```bash
ssh hermes-agent@localhost -p 2222     # with a key installed per agent-base's SSH notes
```

State lives in `~/.hermes` on the host, mounted at `/home/workspace/.hermes`.
The container is stateless; upgrading is a pull, and the data directory is
untouched.

## Entrypoint

`ENTRYPOINT` is `hermes-dev-entrypoint`, which starts sshd and then dispatches
on its first argument:

| Argument | Behaviour |
| --- | --- |
| `workspace` (default) | gateway + dashboard + the workspace server |
| `hermes-agent` / `agent` | the Hermes CLI as the `hermes-agent` account |
| `hermes-agent-server` | gateway + dashboard only |
| a Hermes subcommand | run as the `hermes-agent` account |
| anything else | executed as given |

It drops privileges with `gosu`, and prepares the agent's cache and config
directories plus the CLI install trees. Those paths are **derived** — from
`AGENT_CLI_PREFIX` and `npm root -g` — rather than hardcoded, because a wrong
literal there would be a silent no-op rather than an error.

## Pointing Hermes at a local Ollama

```bash
make gateway-ollama    # prints the config snippet
```

```yaml
model:
  provider: custom
  model: <model-name>
  base_url: http://host.docker.internal:11434/v1
  api_key: "none"
```

On Linux, replace `host.docker.internal` with your host's address.

## Smoke test

A bare `--version` passes on a venv whose site-packages are unloadable, so
`make smoke` asserts the imports instead: that the venv reports the pinned
interpreter, that the OpenAI SDK imports and carries the applied compatibility
patch, that the inherited Node, `uv` and `gosu` are intact, and that no
hardcoded global npm prefix survived.

See [the repository README](../README.md) for how pinning works across all five
images.
