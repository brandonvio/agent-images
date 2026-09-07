# syntax=docker/dockerfile:1.7
#
# openclaw — the OpenClaw gateway on the agent-base developer image, with its
# own account, state directory and SSH host-key location.
#
# Build with:  make build      (thin wrapper around `docker buildx bake`)

ARG AGENT_BASE_IMAGE=brandonvio/agent-base:latest
FROM ${AGENT_BASE_IMAGE}

ARG OPENCLAW_VERSION

ENV HOME=/home/openclaw \
    OPENCLAW_HOME=/home/openclaw/.openclaw \
    OPENCLAW_STATE_DIR=/home/openclaw/.openclaw \
    AGENT_SSH_HOST_KEYS_DIR=/home/openclaw/ssh-host-keys \
    AGENT_SSH_AUTHORIZED_USERS=openclaw

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY entrypoint.sh /entrypoint.sh

RUN set -euo pipefail && \
    chmod +x /entrypoint.sh && \
    npm install -g "openclaw@${OPENCLAW_VERSION}" && \
    npm cache clean --force && \
    chmod -R a+rX "$(npm root -g)" && \
    ln -sf "$(npm prefix -g)/bin/openclaw" /usr/local/bin/openclaw && \
    openclaw --version && \
    mkdir -p /home/openclaw/.openclaw /home/openclaw/.ssh /home/openclaw/ssh-host-keys && \
    chown -R openclaw:openclaw /home/openclaw && \
    chmod -R u+rwX,go-rwX /home/openclaw && \
    printf '%s\n' \
      'export OPENCLAW_HOME=/home/openclaw/.openclaw' \
      'export OPENCLAW_STATE_DIR=/home/openclaw/.openclaw' \
      > /etc/profile.d/openclaw-env.sh && \
    chmod 0644 /etc/profile.d/openclaw-env.sh && \
    mkdir -p /etc/zsh && \
    touch /etc/zsh/zshenv && \
    printf '%s\n' \
      '# OpenClaw defaults for SSH shells.' \
      'export OPENCLAW_HOME=/home/openclaw/.openclaw' \
      'export OPENCLAW_STATE_DIR=/home/openclaw/.openclaw' \
      >> /etc/zsh/zshenv

ARG SOURCE_COMMIT=""
ARG BUILD_DATE=""
ARG BUILD_VERSION=""
ARG AGENT_BASE_DIGEST=""

LABEL org.opencontainers.image.title="openclaw" \
      org.opencontainers.image.description="OpenClaw gateway on the agent-base developer image." \
      org.opencontainers.image.source="https://github.com/brandonvio/agent-images" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      io.brandonvio.openclaw.version="${OPENCLAW_VERSION}" \
      io.brandonvio.openclaw.agent-base.digest="${AGENT_BASE_DIGEST}"

WORKDIR /workspace
USER root
EXPOSE 22 18789
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["gateway"]
