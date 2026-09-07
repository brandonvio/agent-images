# syntax=docker/dockerfile:1.7
#
# hermes harness — the published brandonvio/hermes image, configured to run its
# default agent against the OpenAI API.
#
# This image contains no credential. OPENAI_API_KEY is supplied at run time and
# never baked: an ENV in a Dockerfile is a layer, readable by anyone who pulls
# the image.
#
# The base is pinned by digest. Refresh it with:
#   docker buildx imagetools inspect brandonvio/hermes:latest \
#     --format '{{ .Manifest.Digest }}'

ARG HERMES_IMAGE=brandonvio/hermes:latest@sha256:d8e0e5eaccbb8e0158baa84659bb8b98bc0e7dd82c6ae4ff0201585572540684
FROM ${HERMES_IMAGE}

# The model the default agent boots on. `openai-api` is the API-key provider in
# Hermes's registry; it reads OPENAI_API_KEY directly and needs no `hermes
# login`. Naming it explicitly matters: with provider `auto`, a bare
# OPENAI_API_KEY resolves to OpenRouter, not to OpenAI.
ENV HARNESS_MODEL=gpt-5.6-luna \
    HARNESS_PROVIDER=openai-api \
    HARNESS_BASE_URL=https://api.openai.com/v1

COPY entrypoint.sh /usr/local/bin/hermes-harness-entrypoint
RUN chmod +x /usr/local/bin/hermes-harness-entrypoint

# Chains into the image's own entrypoint, which starts sshd, drops privileges
# with gosu and dispatches on the first argument. The default stays `workspace`.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/hermes-harness-entrypoint"]
CMD ["workspace"]
