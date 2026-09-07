# harness

A local harness for the two agent images, in two flavours.

**Pull-only — builds nothing.** One compose file per agent, each standing alone,
running the published image straight from Docker Hub with your OpenAI key:

```bash
make hermes-up          # harness/hermes/docker-compose.yml
make openclaw-up        # harness/openclaw/docker-compose.yml
make hermes-down
make openclaw-down
```

**Built — a thin layer per agent.** Adds an entrypoint wrapper on top of the
published image, pinned by digest, for when you want the configuration baked in
rather than expressed in compose:

```bash
make build
make up
make logs
make down
```

Both flavours publish the same ports, so run one or the other, not both.

| Service | URL | What |
| --- | --- | --- |
| hermes | http://127.0.0.1:3000 | workspace UI — terminals, files, agents |
| hermes | http://127.0.0.1:8642 | gateway API |
| openclaw | http://127.0.0.1:18789 | gateway and Control UI |

`ssh` is on 2222 for hermes and 2223 for openclaw. Every port is published on
loopback only — these containers hold your API key and serve terminal-capable
endpoints, so they are not exposed to the LAN by default.

## Secrets

`make secrets` generates what the images require into the gitignored `.env`,
skipping anything already there:

| Variable | Why |
| --- | --- |
| `HERMES_API_TOKEN` | the gateway's API server refuses a key under 16 characters — that endpoint dispatches terminal-capable agent work, so a guessable key is remote code execution |
| `HERMES_PASSWORD` | the workspace refuses a non-loopback bind without one |
| `OPENCLAW_GATEWAY_TOKEN` | the openclaw gateway refuses to start without one |

`hermes-up`, `openclaw-up` and `up` depend on it, so it runs on its own.

## Three gates hermes will not let you skip

The published image refuses to start in three separate places, each for a real
reason, and the compose files answer all three:

1. **Gateway as root.** `workspace` mode runs as root by design; the entrypoint
   that drops privileges does not serve the workspace UI. Answered with
   `HERMES_ALLOW_ROOT_GATEWAY=1`.
2. **Dashboard on a non-loopback bind.** It refuses until an auth provider is
   registered, and that is config rather than environment — so the dashboard is
   **off** (`HERMES_START_DASHBOARD=0`) and the workspace UI on `:3000` is the
   way in. To enable it, set `dashboard.basic_auth.username` and
   `password_hash` in `config.yaml` inside the volume, then set
   `HERMES_START_DASHBOARD=1` and publish 9119.
3. **Workspace on a non-loopback bind without a password.** Answered with a
   generated `HERMES_PASSWORD` rather than the `HERMES_ALLOW_INSECURE_REMOTE`
   bypass.

## The key is never in an image

`OPENAI_API_KEY` is read from the repo-root `.env` at run time. It is not
written into a Dockerfile, a config file, or an image layer — an `ENV` line is a
layer, readable by anyone who pulls the image.

The root `.env` also holds `DOCKER_PAT`. That is a registry credential with no
business inside an agent container, so the compose file maps **only**
`OPENAI_API_KEY` through; the `--env-file` in the Makefile is for compose's own
interpolation, not a blanket pass-through. `make check` confirms the key is
readable without printing it.

## Choosing the model

Defaults are `gpt-5.6-luna` for hermes and `openai/gpt-5.6-luna` for openclaw.
Override per run:

```bash
HERMES_MODEL=gpt-5.5 OPENCLAW_MODEL=openai/gpt-5.5 make up
```

`gpt-5.6-luna` is newer than the catalog bundled in either image — hermes's
`openai-api` catalog tops out at `gpt-5.5`, and openclaw's does too. That is
fine: both pass an unrecognised model id straight through to the API, so the
model works as soon as your account has it. What you lose is catalog metadata —
context window and pricing are unknown, so openclaw shows a default context
window rather than the real one, and neither image can infer the provider from
the model name. That last point is why the harness names the provider and
runtime explicitly rather than relying on auto-detection.

## Two things that would otherwise waste an afternoon

**hermes — a bare key resolves to OpenRouter, not OpenAI.** Hermes's provider
auto-detection treats `OPENAI_API_KEY` as an OpenRouter credential. The harness
names the provider explicitly (`openai-api`, the API-key provider in Hermes's
registry, which reads the key straight from the environment with no
`hermes login`).

**hermes — config.yaml and the environment disagree on purpose.** At startup
Hermes prefers `HERMES_MODEL`; from the first turn onward its per-turn sync
prefers `config.yaml`, so that a model change made in the dashboard reaches an
open chat. Setting only the environment gets you an agent that boots on your
model and then quietly reverts. The harness sets both, and seeds `config.yaml`
**only when the data directory has none** — after first boot that file is yours,
and a restart leaves it alone.

**openclaw — an API key alone does not drive `openai/*`.** Those model refs
route to the native Codex app-server harness, which wants a ChatGPT OAuth
sign-in. The API-key route is OpenClaw's own runtime, selected per provider, so
the harness sets `models.providers.openai.agentRuntime.id = openclaw` alongside
the model. Both are written only when absent or unset, because `config set`
rewrites the file and rolls its single backup even when the value is unchanged.

Note the openclaw base image's own entrypoint still rewrites its gateway keys
(bind, auth, token, Control UI) on every start. That is upstream behaviour this
harness does not change.

## How each flavour applies the configuration

The pull-only files reach the same end state as the built images by a different
route, because there is no wrapper entrypoint to lean on.

**hermes needs no wrapper at all.** Everything it requires is environment:
`HERMES_MODEL` and `HERMES_INFERENCE_MODEL` for the model, and
`HERMES_INFERENCE_PROVIDER=openai-api` for the provider. This works precisely
because the volume starts empty — with no `config.yaml`, the per-turn sync falls
back to the same environment the startup path reads, so both agree. Verified on
a fresh volume:

```
startup model    ('gpt-5.6-luna', None)
per-turn target  ('gpt-5.6-luna', '')
provider         openai-api → https://api.openai.com/v1   (key source: env:OPENAI_API_KEY)
```

Once you choose a model in the dashboard, Hermes writes `config.yaml` and that
file wins from then on. That is the intended behaviour. `docker compose down -v`
returns you to what the environment says.

**openclaw needs a few lines.** It has no environment variable for the default
model — that setting lives in config — so its compose file overrides the
entrypoint with a short script that writes the two keys and then execs the
image's own entrypoint. Each key is written only when absent, so a restart
changes nothing:

```
openclaw-compose: set agents.defaults.model.primary = openai/gpt-5.6-luna
openclaw-compose: set models.providers.openai.agentRuntime.id = openclaw
# after a restart:
openclaw-compose: agents.defaults.model.primary is already openai/gpt-5.6-luna, leaving it alone
```

## Bases are pinned

The two Dockerfiles pin their `FROM` by digest, like everything else in this
repo. The pull-only compose files deliberately track `:latest` with
`pull_policy: always`, since running the current published image is their whole
purpose — set `HERMES_IMAGE` or `OPENCLAW_IMAGE` to a digest to pin them too.
To move them forward:

```bash
make pull-bases
make digests        # prints the current digests
```

then paste into the `ARG HERMES_IMAGE` / `ARG OPENCLAW_IMAGE` defaults and
rebuild.

## State

Each agent keeps its state in a named volume — `hermes-data` and
`openclaw-data` — so restarts and rebuilds preserve sessions, credentials and
any model you picked in the UI. `make down` keeps them; remove them explicitly
with `docker volume rm agent-harness_hermes-data agent-harness_openclaw-data`.

`harness/workspace/` is mounted into hermes at `/workspace` as its working
directory and is not tracked.
