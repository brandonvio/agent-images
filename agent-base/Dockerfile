# syntax=docker/dockerfile:1.7
#
# agent-base — a general-purpose Ubuntu 24.04 development image for coding
# agents and the humans who supervise them.
#
# Exactly one Python and exactly one Node, both provisioned to shared /opt
# prefixes so every account in the image can use them, and both reachable
# through /usr/local/bin. Every externally fetched artifact is pinned by exact
# version and verified by sha256; see pins.json and docker-bake.hcl.
#
# Build with:  make build      (thin wrapper around `docker buildx bake`)

ARG UBUNTU_IMAGE=ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517
FROM ${UBUNTU_IMAGE}

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NVM_DIR=/opt/nvm \
    UV_PYTHON_INSTALL_DIR=/opt/python \
    UV_PYTHON_BIN_DIR=/usr/local/bin \
    AGENT_CLI_PREFIX=/opt/agent-cli \
    GOROOT=/usr/local/go \
    GOPATH=/root/go \
    CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    npm_config_install_links=false \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/local/go/bin:/root/go/bin:/usr/local/cargo/bin:/usr/sbin:/usr/bin:/sbin:/bin

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ---------------------------------------------------------------------------
# System packages
#
# The compiler/-dev set (build-essential, clang, cmake, autoconf, automake,
# bison, gettext, pkg-config, lib*-dev, uuid-dev, tk-dev, zlib1g-dev) is a
# deliberate keep: nothing in this build needs it any more, but it is genuinely
# useful in a general-purpose development image.
#
# gosu is also a deliberate keep — no build step uses it, but the entrypoints of
# images built FROM this one exec it to drop privileges at runtime.
# ---------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      apt-transport-https \
      autoconf \
      automake \
      bash \
      bat \
      bison \
      build-essential \
      ca-certificates \
      clang \
      cmake \
      curl \
      direnv \
      dnsutils \
      fd-find \
      file \
      fish \
      fonts-liberation \
      fzf \
      gdb \
      gettext \
      gh \
      git \
      git-lfs \
      gnupg \
      gosu \
      htop \
      iproute2 \
      iputils-ping \
      jq \
      less \
      libasound2t64 \
      libatk-bridge2.0-0 \
      libbz2-dev \
      libcairo2 \
      libdrm2 \
      libffi-dev \
      libgbm1 \
      liblzma-dev \
      libncursesw5-dev \
      libnss3 \
      libpango-1.0-0 \
      libreadline-dev \
      libsqlite3-dev \
      libssl-dev \
      libxcomposite1 \
      libxdamage1 \
      libxfixes3 \
      libxkbcommon0 \
      libxrandr2 \
      locales \
      lsb-release \
      lsof \
      make \
      nano \
      net-tools \
      netcat-openbsd \
      openssh-client \
      openssh-server \
      patch \
      pkg-config \
      procps \
      ripgrep \
      rsync \
      shfmt \
      shellcheck \
      socat \
      sqlite3 \
      strace \
      sudo \
      tcpdump \
      tini \
      tk-dev \
      tmux \
      tree \
      tzdata \
      unzip \
      uuid-dev \
      vim \
      wget \
      xz-utils \
      yq \
      zip \
      zlib1g-dev \
      zsh && \
    locale-gen en_US.UTF-8 && \
    git lfs install --system && \
    ln -sf /usr/bin/batcat /usr/local/bin/bat && \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd && \
    mkdir -p /run/sshd /var/lib/agent-base/ssh-host-keys /ms-playwright && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# uv + the one CPython
#
# uv is fetched as a pinned, sha256-verified release archive. It then installs
# the single CPython this image contracts into /opt/python, and writes the
# /usr/local/bin shims that are the image's actual Python contract.
#
# Package and environment management here is uv (uv venv, uv pip, uv add,
# uv run). ensurepip runs once so that `python3 -m pip` exists for tools that
# shell out to it — no global pip/pip3 shim is created. uv marks its managed
# interpreters PEP 668 externally-managed; that marker is dropped because the
# escape hatch it blocks is exactly the one being kept open on purpose.
# ---------------------------------------------------------------------------
ARG UV_VERSION
ARG UV_SHA256_AMD64
ARG UV_SHA256_ARM64
ARG PYTHON_VERSION

RUN set -euo pipefail && \
    case "${TARGETARCH}" in \
      amd64) uv_triple=x86_64-unknown-linux-gnu; uv_sha="${UV_SHA256_AMD64}" ;; \
      arm64) uv_triple=aarch64-unknown-linux-gnu; uv_sha="${UV_SHA256_ARM64}" ;; \
      *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    curl -fsSLo /tmp/uv.tar.gz \
      "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${uv_triple}.tar.gz" && \
    echo "${uv_sha}  /tmp/uv.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/uv.tar.gz -C /usr/local/bin --strip-components=1 \
      "uv-${uv_triple}/uv" "uv-${uv_triple}/uvx" && \
    rm /tmp/uv.tar.gz && \
    uv --version && uvx --version && \
    uv python install "${PYTHON_VERSION}" && \
    python_bin="$(uv python find "${PYTHON_VERSION}")" && \
    test -x "${python_bin}" && \
    ln -sf "${python_bin}" /usr/local/bin/python3 && \
    ln -sf python3 /usr/local/bin/python && \
    rm -f "$(python3 -c 'import sysconfig; print(sysconfig.get_path("stdlib"))')/EXTERNALLY-MANAGED" && \
    python3 -m ensurepip --upgrade && \
    chmod -R a+rX /opt/python && \
    python3 --version && \
    python3 -c 'import sys; assert sys.base_prefix.startswith("/opt/python"), sys.base_prefix'

# ---------------------------------------------------------------------------
# nvm + the one Node
#
# nvm is checked out at a pinned commit and is present as an escape hatch, but
# it is not the access path: the Node tarball is fetched and sha256-verified
# directly into nvm's own layout, and /usr/local/bin/{node,npm,npx} are the
# runtime contract. Nothing at runtime needs nvm.sh to have been sourced.
# ---------------------------------------------------------------------------
ARG NVM_VERSION
ARG NVM_COMMIT
ARG NODE_VERSION
ARG NODE_SHA256_AMD64
ARG NODE_SHA256_ARM64

RUN set -euo pipefail && \
    case "${TARGETARCH}" in \
      amd64) node_arch=x64; node_sha="${NODE_SHA256_AMD64}" ;; \
      arm64) node_arch=arm64; node_sha="${NODE_SHA256_ARM64}" ;; \
      *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    mkdir -p "${NVM_DIR}" && \
    git -C "${NVM_DIR}" init -q && \
    git -C "${NVM_DIR}" remote add origin https://github.com/nvm-sh/nvm.git && \
    git -C "${NVM_DIR}" fetch -q --depth 1 origin "${NVM_COMMIT}" && \
    git -C "${NVM_DIR}" checkout -q FETCH_HEAD && \
    test -r "${NVM_DIR}/nvm.sh" && \
    node_root="${NVM_DIR}/versions/node/v${NODE_VERSION}" && \
    mkdir -p "${node_root}" && \
    curl -fsSLo /tmp/node.tar.xz \
      "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" && \
    echo "${node_sha}  /tmp/node.tar.xz" | sha256sum -c - && \
    tar -xJf /tmp/node.tar.xz -C "${node_root}" --strip-components=1 && \
    rm /tmp/node.tar.xz && \
    ln -sf "${node_root}/bin/node" /usr/local/bin/node && \
    ln -sf "${node_root}/bin/npm" /usr/local/bin/npm && \
    ln -sf "${node_root}/bin/npx" /usr/local/bin/npx && \
    . "${NVM_DIR}/nvm.sh" && nvm alias default "${NODE_VERSION}" && \
    chmod -R a+rX "${NVM_DIR}" && \
    node --version && npm --version && \
    node -e 'process.exit(process.execPath.startsWith("/opt/nvm/") ? 0 : 1)' && \
    echo "npm global root: $(npm root -g)"

# ---------------------------------------------------------------------------
# Go, Rust, and the Kubernetes/GitOps CLIs — general-purpose tools this image
# ships, each pinned by exact version and (for the raw downloads) sha256.
# ---------------------------------------------------------------------------
ARG GO_VERSION
ARG GO_SHA256_AMD64
ARG GO_SHA256_ARM64
ARG KUBECTL_VERSION
ARG KUBECTL_SHA256_AMD64
ARG KUBECTL_SHA256_ARM64
ARG ARGOCD_VERSION
ARG ARGOCD_SHA256_AMD64
ARG ARGOCD_SHA256_ARM64

RUN set -euo pipefail && \
    case "${TARGETARCH}" in \
      amd64) go_sha="${GO_SHA256_AMD64}"; kubectl_sha="${KUBECTL_SHA256_AMD64}"; argocd_sha="${ARGOCD_SHA256_AMD64}" ;; \
      arm64) go_sha="${GO_SHA256_ARM64}"; kubectl_sha="${KUBECTL_SHA256_ARM64}"; argocd_sha="${ARGOCD_SHA256_ARM64}" ;; \
      *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    curl -fsSLo /tmp/go.tar.gz \
      "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" && \
    echo "${go_sha}  /tmp/go.tar.gz" | sha256sum -c - && \
    rm -rf /usr/local/go && \
    tar -xzf /tmp/go.tar.gz -C /usr/local && \
    rm /tmp/go.tar.gz && \
    curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" && \
    echo "${kubectl_sha}  /usr/local/bin/kubectl" | sha256sum -c - && \
    curl -fsSLo /usr/local/bin/argocd \
      "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${TARGETARCH}" && \
    echo "${argocd_sha}  /usr/local/bin/argocd" | sha256sum -c - && \
    chmod +x /usr/local/bin/kubectl /usr/local/bin/argocd && \
    go version && kubectl version --client=true && argocd version --client

ARG RUST_VERSION
RUN set -euo pipefail && \
    curl --proto '=https' --tlsv1.2 -fsSLo /tmp/rustup-init.sh https://sh.rustup.rs && \
    sh /tmp/rustup-init.sh -y --no-modify-path --profile default \
      --default-toolchain "${RUST_VERSION}" && \
    rm /tmp/rustup-init.sh && \
    chmod -R a+rX "${RUSTUP_HOME}" "${CARGO_HOME}" && \
    rustc --version && cargo --version

# ---------------------------------------------------------------------------
# Shell environment
# ---------------------------------------------------------------------------
ARG OH_MY_ZSH_COMMIT
ARG ZSH_AUTOSUGGESTIONS_COMMIT
ARG ZSH_SYNTAX_HIGHLIGHTING_COMMIT
ARG ZSH_COMPLETIONS_COMMIT

COPY scripts/agent-start-sshd /usr/local/sbin/agent-start-sshd
COPY scripts/zshrc /etc/zsh/zshrc

RUN set -euo pipefail && \
    chmod +x /usr/local/sbin/agent-start-sshd && \
    printf '%s\n' \
      'PermitRootLogin yes' \
      'PubkeyAuthentication yes' \
      'PasswordAuthentication no' \
      'KbdInteractiveAuthentication no' \
      'UsePAM yes' \
      'X11Forwarding no' \
      'AllowTcpForwarding yes' \
      'GatewayPorts yes' \
      > /etc/ssh/sshd_config.d/99-agent-base-root-admin.conf && \
    for spec in \
      "/opt/oh-my-zsh|https://github.com/ohmyzsh/ohmyzsh.git|${OH_MY_ZSH_COMMIT}" \
      "/opt/oh-my-zsh/custom/plugins/zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git|${ZSH_AUTOSUGGESTIONS_COMMIT}" \
      "/opt/oh-my-zsh/custom/plugins/zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git|${ZSH_SYNTAX_HIGHLIGHTING_COMMIT}" \
      "/opt/oh-my-zsh/custom/plugins/zsh-completions|https://github.com/zsh-users/zsh-completions.git|${ZSH_COMPLETIONS_COMMIT}" ; do \
      dest="${spec%%|*}"; rest="${spec#*|}"; url="${rest%%|*}"; sha="${rest#*|}"; \
      mkdir -p "${dest}" && \
      git -C "${dest}" init -q && \
      git -C "${dest}" remote add origin "${url}" && \
      git -C "${dest}" fetch -q --depth 1 origin "${sha}" && \
      git -C "${dest}" checkout -q FETCH_HEAD || exit 1; \
    done && \
    chmod -R a+rX /opt/oh-my-zsh /etc/zsh/zshrc

# ---------------------------------------------------------------------------
# Accounts
# ---------------------------------------------------------------------------
RUN groupadd --gid 10000 agent || true && \
    chsh -s /usr/bin/zsh root && \
    useradd --uid 10000 --gid 10000 --home-dir /opt/data --shell /usr/bin/zsh hermes || true && \
    useradd --uid 10010 --gid 10000 --home-dir /home/workspace --shell /usr/bin/zsh workspace || true && \
    useradd --uid 10020 --home-dir /home/openclaw --shell /usr/bin/zsh --groups sudo openclaw || true && \
    useradd --uid 10030 --gid 10000 --home-dir /opt/data/home --shell /usr/bin/zsh --create-home hermes-agent || true && \
    printf '%s\n' \
      'root ALL=(ALL) NOPASSWD:ALL' \
      'hermes ALL=(ALL) NOPASSWD:ALL' \
      'workspace ALL=(ALL) NOPASSWD:ALL' \
      'openclaw ALL=(ALL) NOPASSWD:ALL' \
      'hermes-agent ALL=(ALL) NOPASSWD:ALL' \
      > /etc/sudoers.d/agent-admins && \
    chmod 0440 /etc/sudoers.d/agent-admins && \
    mkdir -p /opt/data/home /home/workspace /home/openclaw /workspace /root/.ssh && \
    chmod 700 /root/.ssh && \
    chown -R hermes-agent:agent /opt/data/home && \
    chmod 755 /opt/data/home && \
    chmod -R a+rwX /opt/data /home/workspace /home/openclaw /workspace /ms-playwright /var/lib/agent-base

# ---------------------------------------------------------------------------
# AI agent CLIs
#
# Installed from a committed lockfile so the entire transitive tree is pinned,
# not just the top-level CLI version. A nightly pin-refresh job rewrites
# package.json / package-lock.json when upstream publishes a new release.
# ---------------------------------------------------------------------------
COPY package.json package-lock.json ${AGENT_CLI_PREFIX}/

RUN set -euo pipefail && \
    cd "${AGENT_CLI_PREFIX}" && \
    npm ci --omit=dev && \
    for entry in "${AGENT_CLI_PREFIX}"/node_modules/.bin/*; do \
      [ -e "${entry}" ] || continue; \
      ln -sf "${entry}" "/usr/local/bin/$(basename "${entry}")"; \
    done && \
    apt-get update && \
    "${AGENT_CLI_PREFIX}/node_modules/.bin/playwright" install --with-deps chromium && \
    rm -rf /var/lib/apt/lists/* && \
    chromium_bin="$(find /ms-playwright -path '*/chrome-linux*/chrome' -type f | sort | tail -n 1)" && \
    test -n "${chromium_bin}" && \
    ln -sf "${chromium_bin}" /usr/local/bin/chromium && \
    ln -sf "${chromium_bin}" /usr/local/bin/chromium-browser && \
    ln -sf "${chromium_bin}" /usr/local/bin/google-chrome && \
    npm cache clean --force && \
    chmod -R a+rX "${AGENT_CLI_PREFIX}" /ms-playwright && \
    claude --version && codex --version && \
    install -d -m 775 -o hermes-agent -g agent \
      /opt/data/home/.npm \
      /opt/data/home/.cache \
      /opt/data/home/.config \
      /opt/data/home/.local \
      /opt/data/home/.local/bin && \
    chown -Rh hermes-agent:agent \
      /usr/local/bin/codex \
      /usr/local/bin/claude \
      "${AGENT_CLI_PREFIX}" \
      "$(npm root -g)" \
      /usr/local/share \
      /opt/data/home \
      /ms-playwright && \
    chmod 755 /opt/data/home && \
    chmod -R u+rwX,g+rwX \
      "${AGENT_CLI_PREFIX}" \
      "$(npm root -g)" \
      /usr/local/share \
      /opt/data/home/.npm \
      /opt/data/home/.cache \
      /opt/data/home/.config \
      /opt/data/home/.local \
      /ms-playwright

# ---------------------------------------------------------------------------
# Provenance and contents, answerable from `docker inspect`.
# ---------------------------------------------------------------------------
ARG SOURCE_COMMIT=""
ARG BUILD_DATE=""
ARG BUILD_VERSION=""
ARG CLAUDE_CODE_VERSION=""
ARG CODEX_VERSION=""

LABEL org.opencontainers.image.title="agent-base" \
      org.opencontainers.image.description="Ubuntu 24.04 development base for coding agents: one pinned Python, one pinned Node, Go, Rust, and the Claude Code and Codex CLIs." \
      org.opencontainers.image.source="https://github.com/brandonvio/agent-images" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      io.brandonvio.agent-base.python.version="${PYTHON_VERSION}" \
      io.brandonvio.agent-base.node.version="${NODE_VERSION}" \
      io.brandonvio.agent-base.uv.version="${UV_VERSION}" \
      io.brandonvio.agent-base.nvm.version="${NVM_VERSION}" \
      io.brandonvio.agent-base.go.version="${GO_VERSION}" \
      io.brandonvio.agent-base.rust.version="${RUST_VERSION}" \
      io.brandonvio.agent-base.kubectl.version="${KUBECTL_VERSION}" \
      io.brandonvio.agent-base.argocd.version="${ARGOCD_VERSION}" \
      io.brandonvio.agent-base.claude-code.version="${CLAUDE_CODE_VERSION}" \
      io.brandonvio.agent-base.codex.version="${CODEX_VERSION}"

ENV PYTHON_VERSION=${PYTHON_VERSION} \
    NODE_VERSION=${NODE_VERSION}

WORKDIR /workspace
EXPOSE 22
CMD ["zsh"]
