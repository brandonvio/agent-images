# openclaw

`brandonvio/openclaw` — the OpenClaw gateway, layered onto
[`agent-base`](../agent-base/README.md). Platforms: `linux/amd64`,
`linux/arm64`.

```bash
docker pull brandonvio/openclaw:latest
```

## Running it

```bash
docker run -d --name openclaw \
  -e OPENCLAW_GATEWAY_TOKEN=<your-token> \
  -p 2222:22 \
  -p 18789:18789 \
  -v openclaw-data:/home/openclaw \
  brandonvio/openclaw:latest
```

Or locally:

```bash
make build AGENT_BASE_IMAGE=brandonvio/agent-base:local
make smoke
make run      # uses a throwaway token, publishes 2222 and 18789
make logs
make stop
```

| Port | What |
| --- | --- |
| 18789 | gateway and Control UI |
| 22 | ssh, as the `openclaw` account |

## Configuration

| Variable | Required | Meaning |
| --- | --- | --- |
| `OPENCLAW_GATEWAY_TOKEN` | yes | Shared token for the gateway and Control UI |
| `OPENCLAW_ALLOW_DEFAULT_GATEWAY_TOKEN` | no | Set to `1` to fall back to `local-dev` instead of exiting. Local use only |
| `OPENCLAW_HOME` / `OPENCLAW_STATE_DIR` | no | Default to `/home/openclaw/.openclaw` |
| `AGENT_SSH_HOST_KEYS_DIR` | no | Defaults to `/home/openclaw/ssh-host-keys` |
| `AGENT_SSH_AUTHORIZED_USERS` | no | Defaults to `openclaw` |

The entrypoint exits rather than starting with no token. Mount a volume at
`/home/openclaw` to persist state, credentials and SSH host keys across
restarts.

The gateway binds off the loopback interface, which requires a Control UI
origin policy. Device pairing is disabled: the dashboard is already protected
by the shared token, and this is a single-user deployment. Treat that token as
the only thing standing between the network and the gateway, and do not expose
port 18789 beyond a network you control.

## Version

OpenClaw is pinned to an exact npm version in `pins.json`, under `manual` — a
person bumps it deliberately; the nightly pin refresh does not touch it. The
smoke test asserts the running binary reports that version, and that the
non-root `openclaw` account can actually run it.

See [the repository README](../README.md) for how pinning works across all five
images.
