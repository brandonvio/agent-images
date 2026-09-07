IMAGE      ?= brandonvio/hermes
TAG        ?= local
IMAGE_REF  ?= $(IMAGE):$(TAG)
PLATFORM   ?= linux/amd64
IMAGE_DIR  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Local-convenience default: pulls the published base. Override for local
# iteration:  make build AGENT_BASE_IMAGE=brandonvio/agent-base:local
AGENT_BASE_IMAGE ?= brandonvio/agent-base:latest

CONTAINER      ?= hermes
DATA_DIR       ?= $(HOME)/.hermes
GATEWAY_PORT   ?= 8642
DASHBOARD_PORT ?= 9119
SSH_PORT       ?= 2222
OLLAMA_HOST    ?= host.docker.internal
OLLAMA_PORT    ?= 11434

export PINS_JSON := $(shell cat $(IMAGE_DIR)/pins.json)
export AGENT_BASE_IMAGE

pin = $(shell python3 -c "import json;print(json.load(open('$(IMAGE_DIR)/$(1)'))$(2))")

export EXPECT_HERMES_PYTHON := $(call pin,pins.json,['managed']['python']['version'])
export EXPECT_HERMES        := $(call pin,pins.json,['manual']['hermes']['version'])
export EXPECT_UV            := $(shell python3 -c "import json;print(json.load(open('$(IMAGE_DIR)/../agent-base/pins.json'))['managed']['uv']['version'])")

SMOKE_ENV := -e EXPECT_HERMES_PYTHON -e EXPECT_HERMES -e EXPECT_UV

.PHONY: help print print-pins build rebuild shell smoke dev-up dev-down dev-logs dev-shell gateway-ollama

help: ## Show this help
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)

print-pins: ## Show the pin values the smoke test asserts against
	@echo "hermes=$(EXPECT_HERMES) python=$(EXPECT_HERMES_PYTHON) uv=$(EXPECT_UV)"

print: ## Show the resolved build arguments
	cd $(IMAGE_DIR) && docker buildx bake --print hermes

build: ## Build the image locally from the committed pins
	cd $(IMAGE_DIR) && docker buildx bake hermes \
	  --set hermes.tags=$(IMAGE_REF) \
	  --set hermes.platform=$(PLATFORM) \
	  --load

rebuild: ## Build without the build cache
	cd $(IMAGE_DIR) && docker buildx bake hermes --no-cache \
	  --set hermes.tags=$(IMAGE_REF) \
	  --set hermes.platform=$(PLATFORM) \
	  --load

shell: ## Open a root shell in the image
	docker run --rm -it $(IMAGE_REF) bash

smoke: ## Assert the image matches the contract in pins.json
	docker run --rm -i $(SMOKE_ENV) --entrypoint bash $(IMAGE_REF) -s < $(IMAGE_DIR)/scripts/smoke.sh
	@# The entrypoint has to actually run: it starts sshd, drops privileges with
	@# gosu, and prepares the agent paths it derives rather than hardcodes.
	@docker run --rm $(IMAGE_REF) version | tee /dev/stderr \
	  | grep -qF "Python: $(EXPECT_HERMES_PYTHON)" \
	  && echo "ok: entrypoint runs and reports the pinned interpreter" \
	  || { echo "FAIL: entrypoint did not report Python $(EXPECT_HERMES_PYTHON)" >&2; exit 1; }

dev-up: ## Start a local Hermes container (workspace + gateway + dashboard)
	mkdir -p $(DATA_DIR) $(HOME)/hermes-workspace
	docker run -d \
	  --name $(CONTAINER) \
	  --restart unless-stopped \
	  -v $(DATA_DIR):/home/workspace/.hermes \
	  -v $(HOME)/hermes-workspace:/workspace \
	  -v $(DATA_DIR)/ssh-host-keys:/var/lib/agent-base/ssh-host-keys \
	  -e HERMES_START_GATEWAY=1 \
	  -e HERMES_START_DASHBOARD=1 \
	  -e HERMES_API_TOKEN=local-dev \
	  -e API_SERVER_KEY=local-dev \
	  -e GATEWAY_ALLOW_ALL_USERS=true \
	  -e COOKIE_SECURE=0 \
	  -p 3000:3000 \
	  -p $(SSH_PORT):22 \
	  -p $(GATEWAY_PORT):8642 \
	  -p $(DASHBOARD_PORT):9119 \
	  $(IMAGE_REF) workspace
	@echo "SSH:        ssh hermes-agent@localhost -p $(SSH_PORT)"
	@echo "Dashboard:  http://localhost:$(DASHBOARD_PORT)"

dev-down: ## Stop and remove the local container
	docker rm -f $(CONTAINER)

dev-logs: ## Follow local container logs
	docker logs -f $(CONTAINER)

dev-shell: ## Open a shell in the running container
	docker exec -it $(CONTAINER) bash

gateway-ollama: ## Print the config snippet for pointing Hermes at a local Ollama
	@echo "Set your model in $(DATA_DIR)/config.yaml:"
	@echo "  model:"
	@echo "    provider: custom"
	@echo "    model: <model-name>"
	@echo "    base_url: http://$(OLLAMA_HOST):$(OLLAMA_PORT)/v1"
	@echo "    api_key: \"none\""
	@echo ""
	@echo "Then: make dev-down && make dev-up"
