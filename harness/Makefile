HARNESS_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ENV_FILE    ?= $(HARNESS_DIR)/../.env

# --env-file feeds ${OPENAI_API_KEY} into compose's interpolation. The compose
# file then maps only that one variable into the containers.
COMPOSE := docker compose --env-file $(ENV_FILE) -f $(HARNESS_DIR)/docker-compose.yml

.PHONY: help check build up down restart logs ps shell-hermes shell-openclaw pull-bases digests

help: ## Show this help
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z-]+:.*##/ {printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)

check: ## Verify the key is readable without printing it
	@test -f $(ENV_FILE) || { echo "missing $(ENV_FILE)"; exit 1; }
	@grep -q '^OPENAI_API_KEY=' $(ENV_FILE) \
	  && echo "ok: OPENAI_API_KEY present in $(ENV_FILE)" \
	  || { echo "FAIL: no OPENAI_API_KEY in $(ENV_FILE)"; exit 1; }

build: check ## Build both harness images
	$(COMPOSE) build

up: check ## Start both agents
	mkdir -p $(HARNESS_DIR)/workspace
	$(COMPOSE) up -d
	@echo "hermes    dashboard  http://localhost:9119   workspace http://localhost:3000"
	@echo "openclaw  control ui http://localhost:18789"

down: ## Stop and remove both containers
	$(COMPOSE) down

restart: ## Restart both containers
	$(COMPOSE) restart

logs: ## Follow both containers' logs
	$(COMPOSE) logs -f

ps: ## Show harness container status
	$(COMPOSE) ps

shell-hermes: ## Shell into the hermes container
	docker exec -it harness-hermes bash

shell-openclaw: ## Shell into the openclaw container
	docker exec -it harness-openclaw bash

pull-bases: ## Pull the published images the harness builds on
	docker pull brandonvio/hermes:latest
	docker pull brandonvio/openclaw:latest

digests: ## Print the current published digests, for refreshing the pinned FROMs
	@for i in hermes openclaw; do \
	  printf '%-9s %s\n' "$$i" "$$(docker buildx imagetools inspect brandonvio/$$i:latest --format '{{ .Manifest.Digest }}')"; \
	done
