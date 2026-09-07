IMAGE      ?= brandonvio/cicd-runner
TAG        ?= local
IMAGE_REF  ?= $(IMAGE):$(TAG)
PLATFORM   ?= linux/amd64
IMAGE_DIR  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

export PINS_JSON := $(shell cat $(IMAGE_DIR)/pins.json)

export EXPECT_RUNNER := $(shell python3 -c "import json;print(json.load(open('$(IMAGE_DIR)/pins.json'))['managed']['runner']['version'])")

.PHONY: help print print-pins build rebuild shell smoke

help: ## Show this help
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-14s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)

print-pins: ## Show the pin values the smoke test asserts against
	@echo "runner=$(EXPECT_RUNNER)"

print: ## Show the resolved build arguments
	cd $(IMAGE_DIR) && docker buildx bake --print cicd-runner

build: ## Build the image locally from the committed pins
	cd $(IMAGE_DIR) && docker buildx bake cicd-runner \
	  --set cicd-runner.tags=$(IMAGE_REF) \
	  --set cicd-runner.platform=$(PLATFORM) \
	  --load

rebuild: ## Build without the build cache
	cd $(IMAGE_DIR) && docker buildx bake cicd-runner --no-cache \
	  --set cicd-runner.tags=$(IMAGE_REF) \
	  --set cicd-runner.platform=$(PLATFORM) \
	  --load

shell: ## Open a shell in the image
	docker run --rm -it --entrypoint sh $(IMAGE_REF)

smoke: ## Assert the image matches the contract in pins.json
	docker run --rm -i -e EXPECT_RUNNER --entrypoint bash $(IMAGE_REF) -s < $(IMAGE_DIR)/scripts/smoke.sh
