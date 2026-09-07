IMAGE      ?= brandonvio/gpu-enabled
TAG        ?= local
IMAGE_REF  ?= $(IMAGE):$(TAG)
PLATFORM   ?= linux/amd64
IMAGE_DIR  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

export PINS_JSON := $(shell cat $(IMAGE_DIR)/pins.json)

export EXPECT_PYTHON := $(shell tr -d '[:space:]' < $(IMAGE_DIR)/.python-version)

.PHONY: help print print-pins build rebuild shell smoke lock

help: ## Show this help
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-14s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)

print-pins: ## Show the pin values the smoke test asserts against
	@echo "python=$(EXPECT_PYTHON)"

print: ## Show the resolved build arguments
	cd $(IMAGE_DIR) && docker buildx bake --print gpu-enabled

build: ## Build the image locally from the committed pins
	cd $(IMAGE_DIR) && docker buildx bake gpu-enabled \
	  --set gpu-enabled.tags=$(IMAGE_REF) \
	  --set gpu-enabled.platform=$(PLATFORM) \
	  --load

rebuild: ## Build without the build cache
	cd $(IMAGE_DIR) && docker buildx bake gpu-enabled --no-cache \
	  --set gpu-enabled.tags=$(IMAGE_REF) \
	  --set gpu-enabled.platform=$(PLATFORM) \
	  --load

lock: ## Regenerate uv.lock from pyproject.toml
	cd $(IMAGE_DIR) && uv lock

shell: ## Open a shell in the image
	docker run --rm -it $(IMAGE_REF) bash

smoke: ## Assert the image matches the contract in the committed lockfiles
	docker run --rm -i -e EXPECT_PYTHON $(IMAGE_REF) bash -s < $(IMAGE_DIR)/scripts/smoke.sh
