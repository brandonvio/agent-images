# syntax=docker/dockerfile:1.7
#
# gpu-enabled — a CUDA + ffmpeg base with the GPU media stack
# (torch, torchaudio, whisperx, pyannote-audio) already installed.
#
# The value here is the several gigabytes of CUDA wheels that are baked in
# once. Child images FROM this one reconcile a small diff against an
# already-populated virtualenv instead of re-downloading those wheels on every
# build — which is also what keeps them from exhausting CI runner disk.
#
# The base is the plain `-runtime` CUDA image, not `-cudnn-runtime`. torch's
# wheels vendor their own cuDNN (newer than the apt one: 9.10.2 vs 9.5.1) and
# load it in preference to anything on the system, so a system cuDNN is 828 MB
# of second copy. The one package that would have used it — ctranslate2, under
# whisperx — declares no nvidia dependencies and preloads nothing on Linux: it
# dlopen()s by soname and takes whatever the loader offers, which made *which*
# copy it got a function of import order. The ld.so.conf.d entry written below
# settles that deterministically in favour of the wheels.
#
# The dependency set is locked: pyproject.toml + uv.lock + .python-version are
# committed and installed with `uv sync --frozen`, so a stale lock fails the
# build instead of silently re-resolving. This image's Python is whatever the
# CUDA/torch wheels require and is pinned independently of agent-base's.
#
# Build with:  make build      (thin wrapper around `docker buildx bake`)

ARG CUDA_IMAGE=nvidia/cuda:12.6.3-runtime-ubuntu24.04@sha256:92906d87596d638d35015c6353053121bd299d25943b875763321653884ba924
ARG UV_IMAGE=ghcr.io/astral-sh/uv:0.12.10@sha256:2bb3ebca0a796a155094a27773d290c4b074572e6107f171d88d086682fd2500

FROM ${UV_IMAGE} AS uv-bin
FROM ${CUDA_IMAGE}

COPY --from=uv-bin /uv /bin/uv

# The CUDA base ships no Python. Rather than take a distro interpreter that
# cannot be pinned to an exact patch, the interpreter is uv-managed and pinned
# in .python-version — which is why UV_PYTHON_DOWNLOADS is left enabled here.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_INSTALL_DIR=/opt/python \
    UV_PYTHON_BIN_DIR=/usr/local/bin \
    UV_HTTP_TIMEOUT=300 \
    UV_PROJECT_ENVIRONMENT=/app/.venv \
    PYTHONUNBUFFERED=1 \
    PATH=/app/.venv/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        ffmpeg && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY .python-version pyproject.toml uv.lock ./

RUN uv python install && \
    chmod -R a+rX /opt/python && \
    uv sync --no-install-project --extra media-gpu --frozen && \
    chmod -R a+rX /app/.venv && \
    uv cache clean && \
    site="$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')" && \
    find "${site}/nvidia" -maxdepth 2 -type d -name lib | sort > /etc/ld.so.conf.d/000-nvidia-wheels.conf && \
    test -s /etc/ld.so.conf.d/000-nvidia-wheels.conf && \
    ldconfig && \
    python -c 'import torch; assert torch.version.cuda is not None, "CPU-only torch wheel"; print("torch", torch.__version__, "cuda", torch.version.cuda)' && \
    python -c 'import ctypes; ctypes.CDLL("libcudnn_ops.so.9"); p=[l.split()[-1] for l in open("/proc/self/maps") if "libcudnn_ops" in l][0]; assert "site-packages" in p, p; print("cudnn resolves to", p)'

ARG SOURCE_COMMIT=""
ARG BUILD_DATE=""
ARG BUILD_VERSION=""

LABEL org.opencontainers.image.title="gpu-enabled" \
      org.opencontainers.image.description="CUDA + ffmpeg base with torch, torchaudio, whisperx and pyannote-audio pre-installed; cuDNN comes from the torch wheels." \
      org.opencontainers.image.source="https://github.com/brandonvio/agent-images" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${BUILD_VERSION}"

CMD ["bash"]
