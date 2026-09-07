# syntax=docker/dockerfile:1.7
#
# openclaw harness — the published brandonvio/openclaw image, configured to run
# its default agent against the OpenAI API.
#
# This image contains no credential. OPENAI_API_KEY is supplied at run time and
# never baked: an ENV in a Dockerfile is a layer, readable by anyone who pulls
# the image.
#
# The base is pinned by digest. Refresh it with:
#   docker buildx imagetools inspect brandonvio/openclaw:latest \
#     --format '{{ .Manifest.Digest }}'

ARG OPENCLAW_IMAGE=brandonvio/openclaw:latest@sha256:14e8e429215e277bb6e3d2d4ac14c5e83f01022892fa3825c0f0520745ecfbf0
FROM ${OPENCLAW_IMAGE}

# `openai/<model>` routes to the native Codex app-server harness by default,
# which wants a ChatGPT OAuth sign-in. The API-key route is the OpenClaw
# runtime, selected per provider — so the harness sets both the model and the
# runtime, or the key is never used.
ENV HARNESS_MODEL=openai/gpt-5.6-luna \
    HARNESS_RUNTIME=openclaw

COPY entrypoint.sh /usr/local/bin/openclaw-harness-entrypoint
RUN chmod +x /usr/local/bin/openclaw-harness-entrypoint

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/openclaw-harness-entrypoint"]
CMD ["gateway"]
