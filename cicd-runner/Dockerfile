# syntax=docker/dockerfile:1.7
#
# cicd-runner — an ephemeral, one-shot CI job runner with its own in-container
# dockerd.
#
# Each container starts dockerd, registers itself as a one-shot ephemeral
# runner against an Actions-compatible forge API, runs exactly one job, and
# exits. There is no long-lived registration to manage and no state to clean up
# between jobs; scale it by starting more containers.
#
# Security caveat: the in-container dockerd runs privileged. Run this under
# whatever VM-grade isolation your platform provides, and treat every job as
# untrusted code with access to that daemon.
#
# Alpine packages are pinned transitively by the digest-pinned base image: an
# exact `apk add pkg=version` pin is not durable, because Alpine's repositories
# garbage-collect superseded package versions and the pin then becomes a build
# failure on a schedule nobody controls. Freezing the base image freezes the
# repository snapshot those packages resolve against, which is the pin that
# actually holds. This is a deliberate exception; do not "fix" it.
#
# Build with:  make build      (thin wrapper around `docker buildx bake`)

ARG DOCKER_DIND_IMAGE=docker:27-dind@sha256:aa3df78ecf320f5fafdce71c659f1629e96e9de0968305fe1de670e0ca9176ce
FROM ${DOCKER_DIND_IMAGE}

ARG TARGETARCH
ARG RUNNER_VERSION
ARG RUNNER_URL_AMD64
ARG RUNNER_SHA256_AMD64

# curl/jq for API registration, git + bash for jobs, nodejs for the JavaScript
# actions (checkout and friends) the runner executes host-side.
RUN apk add --no-cache curl jq git bash nodejs

# The runner binary's download URL and checksum are pinned per architecture in
# pins.json and reach this build through docker-bake.hcl.
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) runner_url="${RUNNER_URL_AMD64}"; runner_sha="${RUNNER_SHA256_AMD64}" ;; \
      *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /usr/local/bin/cicd-runner "${runner_url}"; \
    echo "${runner_sha}  /usr/local/bin/cicd-runner" | sha256sum -c -; \
    chmod +x /usr/local/bin/cicd-runner; \
    cicd-runner --version

COPY config.yaml /etc/cicd-runner/config.yaml
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ARG SOURCE_COMMIT=""
ARG BUILD_DATE=""
ARG BUILD_VERSION=""

LABEL org.opencontainers.image.title="cicd-runner" \
      org.opencontainers.image.description="Ephemeral one-shot CI job runner with an in-container dockerd." \
      org.opencontainers.image.source="https://github.com/brandonvio/agent-images" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.revision="${SOURCE_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      io.brandonvio.cicd-runner.version="${RUNNER_VERSION}"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
