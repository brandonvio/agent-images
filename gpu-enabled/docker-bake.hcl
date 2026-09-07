# Single source of truth for gpu-enabled build arguments.
#
# buildx bake has no file() function, so pins.json is handed in through the
# environment:  PINS_JSON="$(cat pins.json)" docker buildx bake gpu-enabled
#
# The Python set is not duplicated here — it lives in uv.lock and
# .python-version, which the Dockerfile copies and installs with --frozen.

variable "PINS_JSON" {
  default = "{}"
}

pins = jsondecode(PINS_JSON)

variable "IMAGE" {
  default = "brandonvio/gpu-enabled"
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
  targets = ["gpu-enabled"]
}

# amd64 only: the CUDA wheels this image exists to bake in are x86_64.
target "gpu-enabled" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = ["${IMAGE}:${TAG}"]
  platforms  = ["linux/amd64"]

  args = {
    CUDA_IMAGE = pins.managed.cuda.ref
    UV_IMAGE   = pins.managed.uv.ref

    SOURCE_COMMIT = SOURCE_COMMIT
    BUILD_DATE    = BUILD_DATE
    BUILD_VERSION = BUILD_VERSION
  }
}
