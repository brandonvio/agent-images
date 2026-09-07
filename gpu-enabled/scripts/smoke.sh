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

# The lock must be satisfied by what is installed; a drifted lock is a failure
# here rather than a silent re-resolve in a child image's build.
uv sync --no-install-project --extra media-gpu --frozen --check >/dev/null \
  || fail "installed environment does not match uv.lock"
ok "installed environment matches uv.lock"

echo "gpu-enabled smoke: PASS"
