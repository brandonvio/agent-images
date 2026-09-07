# syntax=docker/dockerfile:1.7
#
# hermes — the Hermes agent and its web workspace, layered onto agent-base so
# the same shell, accounts, sshd and developer toolchain are available around
# them.
#
# Hermes ships a prebuilt virtualenv at /opt/hermes/.venv whose compiled
# extension modules carry a 3.13 ABI tag, so this image installs the exact
# interpreter that venv was built for (pinned in pins.json) rather than
# borrowing the newer one agent-base contracts. uv comes from agent-base,
# pinned; it is deliberately not copied out of the upstream image.
#
# Build with:  make build      (thin wrapper around `docker buildx bake`)

ARG HERMES_AGENT_IMAGE=nousresearch/hermes-agent:v2026.7.1@sha256:b6c019227889e6675424a2b6223b2cafdd36bf7d1048d1ddd8e043b880d6cc0f
ARG HERMES_WORKSPACE_IMAGE=ghcr.io/outsourc-e/hermes-workspace:latest@sha256:1ec05339750da7caaf1cd0183c8c3b188856918b377407b4ac1dafca67e42d88
ARG AGENT_BASE_IMAGE=brandonvio/agent-base:latest

FROM ${HERMES_AGENT_IMAGE} AS hermes-agent
FROM ${HERMES_WORKSPACE_IMAGE} AS hermes-workspace

FROM ${AGENT_BASE_IMAGE}

ARG HERMES_VERSION
ARG HERMES_PYTHON_VERSION

ENV HERMES_VERSION=${HERMES_VERSION} \
    HERMES_HOME=/home/workspace/.hermes \
    HERMES_WEB_DIST=/opt/hermes/hermes_cli/web_dist \
    PATH=/opt/hermes/bin:/opt/hermes/.venv/bin:${PATH}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=hermes-agent /opt/hermes /opt/hermes
COPY --from=hermes-workspace /app /opt/hermes-workspace

RUN set -euo pipefail && \
    mkdir -p /opt/data /home/workspace /workspace && \
    chmod -R a+rwX /opt/data /home/workspace /workspace /opt/hermes-workspace && \
    uv python install "${HERMES_PYTHON_VERSION}" && \
    hermes_python="$(uv python find "${HERMES_PYTHON_VERSION}")" && \
    test -x "${hermes_python}" && \
    chmod -R a+rX /opt/python && \
    rm -f /opt/hermes/.venv/bin/python \
          /opt/hermes/.venv/bin/python3 \
          /opt/hermes/.venv/bin/python3.13 && \
    ln -s "${hermes_python}" /opt/hermes/.venv/bin/python && \
    ln -s python /opt/hermes/.venv/bin/python3 && \
    ln -s python /opt/hermes/.venv/bin/python3.13 && \
    printf '%s\n' \
      "home = $(dirname "${hermes_python}")" \
      'include-system-site-packages = false' \
      "version = ${HERMES_PYTHON_VERSION}" \
      > /opt/hermes/.venv/pyvenv.cfg && \
    ln -sf /opt/hermes/.venv/bin/hermes /usr/local/bin/hermes && \
    /opt/hermes/.venv/bin/python -c 'import sys; print(sys.version)' && \
    /opt/hermes/.venv/bin/python -c 'import openai; print("openai", openai.__version__)'

COPY scripts/patch-hermes-codex.py /tmp/patch-hermes-codex.py
RUN /opt/hermes/.venv/bin/python /tmp/patch-hermes-codex.py && \
    rm /tmp/patch-hermes-codex.py

COPY scripts/entrypoint.sh /usr/local/bin/hermes-dev-entrypoint
RUN chmod +x /usr/local/bin/hermes-dev-entrypoint

ENV HERMES_DOCKER_EXEC_AS_ROOT=1

ARG SOURCE_COMMIT=""
ARG BUILD_DATE=""
ARG BUILD_VERSION=""
ARG AGENT_BASE_DIGEST=""

LABEL org.opencontainers.image.title="hermes" \
      org.opencontainers.image.description="Hermes agent and web workspace on the agent-base developer image." \
      org.opencontainers.image.source="https://github.com/brandonvio/agent-images" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      io.brandonvio.hermes.version="${HERMES_VERSION}" \
      io.brandonvio.hermes.python.version="${HERMES_PYTHON_VERSION}" \
      io.brandonvio.hermes.agent-base.digest="${AGENT_BASE_DIGEST}"

WORKDIR /workspace
USER root
EXPOSE 22 3000 8642 9119
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/hermes-dev-entrypoint"]
CMD ["workspace"]
