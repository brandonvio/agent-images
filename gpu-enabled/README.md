# gpu-enabled

`brandonvio/gpu-enabled` — a CUDA + ffmpeg base with the GPU media
stack already installed: `torch`, `torchaudio`, `whisperx` and
`pyannote-audio`. Platform: `linux/amd64`.

```bash
docker pull brandonvio/gpu-enabled:latest
```

## Why it exists

Those wheels are several gigabytes, and downloading them on every build of
every downstream image is slow, fragile, and a reliable way to exhaust a CI
runner's disk. Baking them once means a child image reconciles a small diff
against an already-populated virtualenv instead:

```dockerfile
FROM brandonvio/gpu-enabled:latest
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen        # resolves against what is already installed
COPY . .
```

## Layout

```
/bin/uv                pinned uv, copied from a digest-pinned image
/opt/python            uv-managed CPython, version pinned in .python-version
/app/.venv             the locked environment; first on PATH
/app/{pyproject.toml,uv.lock,.python-version}
```

`NVIDIA_VISIBLE_DEVICES=all` and
`NVIDIA_DRIVER_CAPABILITIES=compute,utility` are set, so
`docker run --gpus all` works without further environment.

## Pinning

The dependency set is locked rather than resolved at build time:
`pyproject.toml` + a committed `uv.lock` + `.python-version`, installed with
`uv sync --frozen`. A stale lock fails the build instead of silently
re-resolving into something else.

The CUDA base image and the `uv` image are pinned by digest in `pins.json`. The
Python set is **not** duplicated there — it lives in `uv.lock`, and one fact
belongs in one file.

This image's Python version is whatever the CUDA and torch wheels require, and
is pinned independently of `agent-base`'s. The two images do not share an
interpreter version by policy, only ever by coincidence. Note that this is why
uv's Python downloads are left enabled here: the CUDA base ships no Python at
all, and a distro interpreter cannot be pinned to an exact patch.

To move the dependency set:

```bash
make lock       # regenerate uv.lock from pyproject.toml
make build
make smoke
```

## Smoke test

`make smoke` runs CPU-only — it must pass on a machine with no GPU, and must
not be changed to require a device. It does assert `torch.version.cuda is not
None`, because a plain `import torch` succeeds on a CPU-only wheel, and that is
precisely the failure that would make an image named `gpu-enabled` a lie. It
also asserts the interpreter matches `.python-version` and that the installed
environment still satisfies `uv.lock`.

See [the repository README](../README.md) for how pinning works across all five
images.
