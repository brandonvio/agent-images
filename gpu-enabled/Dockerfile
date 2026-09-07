# syntax=docker/dockerfile:1.7
#
# gpu-enabled — a CUDA + cuDNN + ffmpeg base with the GPU media stack
# (torch, torchaudio, whisperx, pyannote-audio) already installed.
#
# The value here is the several gigabytes of CUDA wheels that are baked in
# once. Child images FROM this one reconcile a small diff against an
# already-populated virtualenv instead of re-downloading those wheels on every
# build — which is also what keeps them from exhausting CI runner disk.
#
# The dependency set is locked: pyproject.toml + uv.lock + .python-version are
# committed and installed with `uv sync --frozen`, so a stale lock fails the
# build instead of silently re-resolving. This image's Python is whatever the
# CUDA/torch wheels require and is pinned independently of agent-base's.
#
# Build with:  make build      (thin wrapper around `docker buildx bake`)

ARG CUDA_IMAGE=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04@sha256:8aef630a54bc5c5146ae5ce68e6af5caa3df0fb690bb91544175c91f307e4356
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
    python -c 'import torch; assert torch.version.cuda is not None, "CPU-only torch wheel"; print("torch", torch.__version__, "cuda", torch.version.cuda)'

ARG SOURCE_COMMIT=""
ARG BUILD_DATE=""
ARG BUILD_VERSION=""

LABEL org.opencontainers.image.title="gpu-enabled" \
      org.opencontainers.image.description="CUDA + cuDNN + ffmpeg base with torch, torchaudio, whisperx and pyannote-audio pre-installed." \
      org.opencontainers.image.source="https://github.com/brandonvio/agent-images" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${BUILD_VERSION}"

CMD ["bash"]
