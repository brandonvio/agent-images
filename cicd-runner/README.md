# cicd-runner

`brandonvio/cicd-runner` — an ephemeral, one-shot CI job runner with its own
in-container dockerd. Platform: `linux/amd64`.

```bash
docker pull brandonvio/cicd-runner:latest
```

Each container starts dockerd, registers itself as a one-shot ephemeral runner
through an Actions-compatible admin API, runs exactly one job, and exits. The
server removes the ephemeral runner automatically. Scale it by starting more
containers; there is no long-lived registration to manage and no state to clean
up between jobs.

## Security caveat

**The in-container dockerd runs privileged, and every job it executes is
untrusted code with access to that daemon.** Run this under whatever VM-grade
isolation your platform provides. A container boundary alone is not a
sufficient answer to `docker build` executed on behalf of an arbitrary
contributor.

The job bind-mount allowlist in `config.yaml` defaults to `'**'` — any host
path. That is only defensible because the runner is ephemeral, runs a single
job, and is expected to be isolated at the platform level. If any of those
three does not hold where you run it, replace that value with the specific
paths your jobs need.

## Configuration

| Variable | Required | Meaning |
| --- | --- | --- |
| `RUNNER_SERVER_URL` | yes | Base URL of the server the runner registers against |
| `RUNNER_API_TOKEN` | yes | Admin API token used to mint the registration token |
| `RUNNER_LABELS` | no | `runs-on` label and job image. Defaults to `ubuntu-latest:docker://catthehacker/ubuntu:act-22.04` |
| `RUNNER_REGISTER_PATH` | no | Admin endpoint that mints a single-use registration token. Defaults to `/api/v1/admin/actions/runners` |
| `DOCKERD_MTU` | no | Defaults to `1450`. Must not exceed the MTU of the network the container is attached to — when it does, the bridge fragments and large image-layer pulls stall |

```bash
docker run --rm --privileged \
  -e RUNNER_SERVER_URL=https://ci.example.com \
  -e RUNNER_API_TOKEN=<admin-token> \
  brandonvio/cicd-runner:latest
```

## Exit codes

`one-job` exits non-zero with "no task received" when the runner pool was
scaled past the number of queued tasks and another runner claimed the task
first. The entrypoint translates that specific case to exit 0, because it is a
race rather than a failure and treating it as one makes run history unreadable.
Every other non-zero exit is passed through.

## What's installed

`docker:dind` plus `curl`, `jq`, `git`, `bash` and `nodejs` — enough for API
registration and for the JavaScript actions the runner executes host-side. The
runner binary is installed at `/usr/local/bin/cicd-runner` and its config at
`/etc/cicd-runner/config.yaml`.

Alpine packages here are pinned **transitively, by the digest-pinned base
image**. This is deliberate and should not be "fixed" into exact `apk` pins:
Alpine's repositories garbage-collect superseded package versions, so an exact
`apk add pkg=1.2.3-r4` turns into a build failure on a schedule nobody
controls. Freezing the base image freezes the repository snapshot those
packages resolve against, which is the pin that actually holds. The runner
binary itself is pinned by exact version, download URL and sha256 in
`pins.json`.

## Architecture

`amd64` only, which is a scope choice rather than a technical limit — an arm64
runner build is published upstream. Adding it is one more URL, its sha256, and
a second entry in the bake target's platform list.

## Building

```bash
make build
make smoke
```

See [the repository README](../README.md) for how pinning works across all five
images.
