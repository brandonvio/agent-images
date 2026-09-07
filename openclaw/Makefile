IMAGE      ?= brandonvio/openclaw
TAG        ?= local
IMAGE_REF  ?= $(IMAGE):$(TAG)
PLATFORM   ?= linux/amd64
IMAGE_DIR  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Local-convenience default. Override for local iteration:
#   make build AGENT_BASE_IMAGE=brandonvio/agent-base:local
AGENT_BASE_IMAGE ?= brandonvio/agent-base:latest

CONTAINER    ?= openclaw
DATA_VOLUME  ?= openclaw-data
SSH_PORT     ?= 2222
GATEWAY_PORT ?= 18789

export PINS_JSON := $(shell cat $(IMAGE_DIR)/pins.json)
export AGENT_BASE_IMAGE

export EXPECT_OPENCLAW := $(shell python3 -c "import json;print(json.load(open('$(IMAGE_DIR)/pins.json'))['manual']['openclaw']['version'])")

.PHONY: help print print-pins build rebuild run stop logs shell smoke

help: ## Show this help
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-14s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)

print-pins: ## Show the pin values the smoke test asserts against
	@echo "openclaw=$(EXPECT_OPENCLAW)"

print: ## Show the resolved build arguments
	cd $(IMAGE_DIR) && docker buildx bake --print openclaw

build: ## Build the image locally from the committed pins
	cd $(IMAGE_DIR) && docker buildx bake openclaw \
	  --set openclaw.tags=$(IMAGE_REF) \
	  --set openclaw.platform=$(PLATFORM) \
	  --load

rebuild: ## Build without the build cache
	cd $(IMAGE_DIR) && docker buildx bake openclaw --no-cache \
	  --set openclaw.tags=$(IMAGE_REF) \
	  --set openclaw.platform=$(PLATFORM) \
	  --load

run: ## Run the gateway locally
	docker volume create $(DATA_VOLUME) >/dev/null
	docker rm -f $(CONTAINER) >/dev/null 2>&1 || true
	docker run -d \
	  --name $(CONTAINER) \
	  -e OPENCLAW_GATEWAY_TOKEN=local-dev \
	  -e OPENCLAW_ALLOW_DEFAULT_GATEWAY_TOKEN=1 \
	  -p $(SSH_PORT):22 \
	  -p $(GATEWAY_PORT):18789 \
	  -v $(DATA_VOLUME):/home/openclaw \
	  $(IMAGE_REF)
	@echo "SSH:        ssh openclaw@localhost -p $(SSH_PORT)"
	@echo "Control UI: http://localhost:$(GATEWAY_PORT)"
	@echo "Logs:       docker logs -f $(CONTAINER)"

stop: ## Stop and remove the local container
	docker rm -f $(CONTAINER)

logs: ## Follow container logs
	docker logs -f $(CONTAINER)

shell: ## Open a root shell in the running container
	docker exec -it $(CONTAINER) bash

smoke: ## Assert the image matches the contract in pins.json
	docker run --rm -i -e EXPECT_OPENCLAW --entrypoint bash $(IMAGE_REF) -s < $(IMAGE_DIR)/scripts/smoke.sh
	@# The entrypoint has to actually run: it starts sshd and dispatches.
	@docker run --rm -e OPENCLAW_ALLOW_DEFAULT_GATEWAY_TOKEN=1 $(IMAGE_REF) openclaw --version \
	  | grep -qF "$(EXPECT_OPENCLAW)" \
	  && echo "ok: entrypoint runs and dispatches" \
	  || { echo "FAIL: entrypoint dispatch did not report $(EXPECT_OPENCLAW)" >&2; exit 1; }
	@# And it must refuse to start with no token rather than falling back silently.
	@if docker run --rm $(IMAGE_REF) >/dev/null 2>&1; then \
	  echo "FAIL: entrypoint started without OPENCLAW_GATEWAY_TOKEN" >&2; exit 1; \
	else echo "ok: entrypoint refuses to start without a gateway token"; fi
