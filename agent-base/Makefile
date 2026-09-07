IMAGE      ?= brandonvio/agent-base
TAG        ?= local
IMAGE_REF  ?= $(IMAGE):$(TAG)
PLATFORM   ?= linux/amd64
IMAGE_DIR  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# buildx bake cannot read a file itself, so the pin files are handed to it
# through the environment. This is the only place they are read.
export PINS_JSON := $(shell cat $(IMAGE_DIR)/pins.json)
export CLIS_JSON := $(shell cat $(IMAGE_DIR)/package.json)

pin = $(shell python3 -c "import json;print(json.load(open('$(IMAGE_DIR)/$(1)'))$(2))")

export EXPECT_PYTHON  := $(call pin,pins.json,['managed']['python']['version'])
export EXPECT_NODE    := $(call pin,pins.json,['managed']['node']['version'])
export EXPECT_UV      := $(call pin,pins.json,['managed']['uv']['version'])
export EXPECT_GO      := $(call pin,pins.json,['managed']['go']['version'])
export EXPECT_RUST    := $(call pin,pins.json,['managed']['rust']['version'])
export EXPECT_KUBECTL := $(call pin,pins.json,['managed']['kubectl']['version'])
export EXPECT_CLAUDE  := $(call pin,package.json,['dependencies']['@anthropic-ai/claude-code'])
export EXPECT_CODEX   := $(call pin,package.json,['dependencies']['@openai/codex'])

SMOKE_ENV := -e EXPECT_PYTHON -e EXPECT_NODE -e EXPECT_UV -e EXPECT_GO \
             -e EXPECT_RUST -e EXPECT_KUBECTL -e EXPECT_CLAUDE -e EXPECT_CODEX

.PHONY: help print print-pins build rebuild shell smoke versions

help: ## Show this help
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-14s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)

print-pins: ## Show the pin values the smoke test asserts against
	@echo "python=$(EXPECT_PYTHON) node=$(EXPECT_NODE) uv=$(EXPECT_UV) go=$(EXPECT_GO)"
	@echo "rust=$(EXPECT_RUST) kubectl=$(EXPECT_KUBECTL) claude=$(EXPECT_CLAUDE) codex=$(EXPECT_CODEX)"

print: ## Show the resolved build arguments
	cd $(IMAGE_DIR) && docker buildx bake --print agent-base

build: ## Build the image locally from the committed pins
	cd $(IMAGE_DIR) && docker buildx bake agent-base \
	  --set agent-base.tags=$(IMAGE_REF) \
	  --set agent-base.platform=$(PLATFORM) \
	  --load

rebuild: ## Build without the build cache
	cd $(IMAGE_DIR) && docker buildx bake agent-base --no-cache \
	  --set agent-base.tags=$(IMAGE_REF) \
	  --set agent-base.platform=$(PLATFORM) \
	  --load

shell: ## Open a root shell in the image
	docker run --rm -it $(IMAGE_REF) bash

smoke: ## Assert the image matches the contract in pins.json
	docker run --rm -i $(SMOKE_ENV) $(IMAGE_REF) bash -s < $(IMAGE_DIR)/scripts/smoke.sh

versions: smoke ## Alias for smoke
