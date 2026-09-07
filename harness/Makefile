HARNESS_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ENV_FILE    ?= $(HARNESS_DIR)/../.env

# --env-file feeds ${OPENAI_API_KEY} into compose's interpolation. The compose
# file then maps only that one variable into the containers.
COMPOSE := docker compose --env-file $(ENV_FILE) -f $(HARNESS_DIR)/docker-compose.yml

# Pull-only: run the published images straight from Docker Hub, building
# nothing. One compose file per agent, each standing alone.
HERMES_COMPOSE   := docker compose --env-file $(ENV_FILE) -f $(HARNESS_DIR)/hermes/docker-compose.yml
OPENCLAW_COMPOSE := docker compose --env-file $(ENV_FILE) -f $(HARNESS_DIR)/openclaw/docker-compose.yml

.PHONY: help check build up down restart logs ps shell-hermes shell-openclaw pull-bases digests \
        hermes-up hermes-down hermes-logs openclaw-up openclaw-down openclaw-logs secrets

help: ## Show this help
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z-]+:.*##/ {printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)

check: ## Verify the key is readable without printing it
	@test -f $(ENV_FILE) || { echo "missing $(ENV_FILE)"; exit 1; }
	@grep -q '^OPENAI_API_KEY=' $(ENV_FILE) \
	  && echo "ok: OPENAI_API_KEY present in $(ENV_FILE)" \
	  || { echo "FAIL: no OPENAI_API_KEY in $(ENV_FILE)"; exit 1; }

secrets: ## Generate the local secrets hermes requires into .env, if absent
	@touch $(ENV_FILE)
	@# A file whose last line has no newline would otherwise have the next
	@# variable appended to the end of it, silently corrupting that value.
	@if [ -s $(ENV_FILE) ] && [ -n "$$(tail -c1 $(ENV_FILE))" ]; then printf '\n' >> $(ENV_FILE); fi
	@grep -q '^HERMES_API_TOKEN=' $(ENV_FILE) || { \
	  printf 'HERMES_API_TOKEN=%s\n' "$$(openssl rand -hex 32)" >> $(ENV_FILE); \
	  echo "generated HERMES_API_TOKEN into $(ENV_FILE)"; }
	@grep -q '^HERMES_PASSWORD=' $(ENV_FILE) || { \
	  printf 'HERMES_PASSWORD=%s\n' "$$(openssl rand -hex 16)" >> $(ENV_FILE); \
	  echo "generated HERMES_PASSWORD into $(ENV_FILE)"; }
	@grep -q '^OPENCLAW_GATEWAY_TOKEN=' $(ENV_FILE) || { \
	  printf 'OPENCLAW_GATEWAY_TOKEN=%s\n' "$$(openssl rand -hex 32)" >> $(ENV_FILE); \
	  echo "generated OPENCLAW_GATEWAY_TOKEN into $(ENV_FILE)"; }
	@echo "ok: hermes and openclaw secrets present in $(ENV_FILE)"

hermes-up: check secrets ## Run the published hermes image (builds nothing)
	$(HERMES_COMPOSE) up -d
	@echo "hermes  workspace http://127.0.0.1:3000   gateway API http://127.0.0.1:8642"

hermes-down: ## Stop the published hermes container
	$(HERMES_COMPOSE) down

hermes-logs: ## Follow the published hermes container's logs
	$(HERMES_COMPOSE) logs -f

openclaw-up: check secrets ## Run the published openclaw image (builds nothing)
	$(OPENCLAW_COMPOSE) up -d
	@echo "openclaw  control ui http://127.0.0.1:18789"

openclaw-down: ## Stop the published openclaw container
	$(OPENCLAW_COMPOSE) down

openclaw-logs: ## Follow the published openclaw container's logs
	$(OPENCLAW_COMPOSE) logs -f

build: check ## Build both harness images
	$(COMPOSE) build

up: check secrets ## Start both agents
	mkdir -p $(HARNESS_DIR)/workspace
	$(COMPOSE) up -d
	@echo "hermes    dashboard  http://localhost:9119   workspace http://localhost:3000"
	@echo "openclaw  control ui http://127.0.0.1:18789"

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
