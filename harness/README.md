# harness

A local harness for the two agent images. Each service is the published image
from Docker Hub with one thin layer on top that points its **default agent** at
the OpenAI API and then hands off to the image's own entrypoint unchanged.

```bash
make build
make up
make logs
make down
```

| Service | URL | What |
| --- | --- | --- |
| hermes | http://localhost:9119 | dashboard |
| hermes | http://localhost:3000 | workspace server |
| hermes | http://localhost:8642 | gateway API |
| openclaw | http://localhost:18789 | gateway and Control UI |

`ssh` is on 2222 for hermes and 2223 for openclaw.

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

## Bases are pinned

Both Dockerfiles pin their `FROM` by digest, like everything else in this repo.
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
