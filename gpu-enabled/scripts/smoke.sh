#!/usr/bin/env bash
# gpu-enabled smoke test.
#
# Runs CPU-only: it must pass on a runner with no GPU, and must not be changed
# to require a device. It does assert that the installed torch is a CUDA build,
# because a plain `import torch` passes on a CPU-only wheel — which is exactly
# the failure that would make an image named gpu-enabled a lie.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok: $*"; }

got="$(python -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
[ "$got" = "$EXPECT_PYTHON" ] || fail "python $got != pinned $EXPECT_PYTHON"
python -c 'import sys; assert sys.prefix == "/app/.venv", sys.prefix'
ok "python $got from the locked project environment"

uv --version >/dev/null || fail "uv is missing"
ffmpeg -version >/dev/null || fail "ffmpeg is missing"
ok "uv and ffmpeg are present"

python - <<'PY'
import torch, torchaudio, whisperx, pyannote.audio
assert torch.version.cuda is not None, "torch is a CPU-only wheel"
print("torch", torch.__version__, "cuda", torch.version.cuda)
print("torchaudio", torchaudio.__version__)
PY
ok "torch is a CUDA build and the media stack imports"

# The CUDA libraries ctranslate2 dlopen()s must resolve to the torch wheels'
# copies, not to a system CUDA. This is the assertion that keeps the -runtime
# base honest: ctranslate2 declares no nvidia dependencies and preloads nothing
# on Linux, so without the ld.so.conf.d entry the resolution silently depends
# on import order. Loading a library needs no device, so this stays CPU-only.
python - <<'CUDALIBS'
import ctypes
for lib in ("libcudnn_ops.so.9", "libcublas.so.12", "libcudart.so.12"):
    ctypes.CDLL(lib)
    stem = lib.split(".so")[0] + ".so"
    path = [l.split()[-1] for l in open("/proc/self/maps") if stem in l][0]
    assert "site-packages" in path, f"{lib} resolved to {path}, expected a torch wheel"
    print(lib, "->", path)
CUDALIBS
ok "CUDA libraries resolve to the torch wheels"

# The lock must be satisfied by what is installed; a drifted lock is a failure
# here rather than a silent re-resolve in a child image's build.
uv sync --no-install-project --extra media-gpu --frozen --check >/dev/null \
  || fail "installed environment does not match uv.lock"
ok "installed environment matches uv.lock"

echo "gpu-enabled smoke: PASS"
