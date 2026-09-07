# Single source of truth for cicd-runner build arguments.
#
# buildx bake has no file() function, so pins.json is handed in through the
# environment:  PINS_JSON="$(cat pins.json)" docker buildx bake cicd-runner

variable "PINS_JSON" {
  default = "{}"
}

pins = jsondecode(PINS_JSON)

variable "IMAGE" {
  default = "brandonvio/cicd-runner"
}

variable "TAG" {
  default = "local"
}

variable "SOURCE_COMMIT" {
  default = ""
}

variable "BUILD_DATE" {
  default = ""
}

variable "BUILD_VERSION" {
  default = ""
}

group "default" {
  targets = ["cicd-runner"]
}

# amd64 only: the runner binary download is architecture-specific and only the
# amd64 build is pinned here. Adding arm64 is one more URL, its sha256, and a
# second entry in the platform list.
target "cicd-runner" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = ["${IMAGE}:${TAG}"]
  platforms  = ["linux/amd64"]

  args = {
    DOCKER_DIND_IMAGE   = pins.managed.docker_dind.ref
    RUNNER_VERSION      = pins.managed.runner.version
    RUNNER_URL_AMD64    = pins.managed.runner.url.amd64
    RUNNER_SHA256_AMD64 = pins.managed.runner.sha256.amd64

    SOURCE_COMMIT = SOURCE_COMMIT
    BUILD_DATE    = BUILD_DATE
    BUILD_VERSION = BUILD_VERSION
  }
}
