# Single source of truth for openclaw build arguments.
#
# buildx bake has no file() function, so pins.json is handed in through the
# environment:  PINS_JSON="$(cat pins.json)" docker buildx bake openclaw

variable "PINS_JSON" {
  default = "{}"
}

pins = jsondecode(PINS_JSON)

variable "IMAGE" {
  default = "brandonvio/openclaw"
}

variable "TAG" {
  default = "local"
}

# Local-convenience default. CI always overrides this with the agent-base index
# digest resolved once per run, so both arch legs provably share one base.
variable "AGENT_BASE_IMAGE" {
  default = "brandonvio/agent-base:latest"
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
  targets = ["openclaw"]
}

target "openclaw" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = ["${IMAGE}:${TAG}"]
  platforms  = ["linux/amd64"]

  args = {
    AGENT_BASE_IMAGE  = AGENT_BASE_IMAGE
    OPENCLAW_VERSION  = pins.manual.openclaw.version

    # Derived from the same value that feeds AGENT_BASE_IMAGE.
    AGENT_BASE_DIGEST = AGENT_BASE_IMAGE

    SOURCE_COMMIT = SOURCE_COMMIT
    BUILD_DATE    = BUILD_DATE
    BUILD_VERSION = BUILD_VERSION
  }
}
