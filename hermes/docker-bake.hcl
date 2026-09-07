# Single source of truth for hermes build arguments.
#
# buildx bake has no file() function, so pins.json is handed in through the
# environment:  PINS_JSON="$(cat pins.json)" docker buildx bake hermes

variable "PINS_JSON" {
  default = "{}"
}

pins = jsondecode(PINS_JSON)

variable "IMAGE" {
  default = "brandonvio/hermes"
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
  targets = ["hermes"]
}

target "hermes" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = ["${IMAGE}:${TAG}"]
  platforms  = ["linux/amd64"]

  args = {
    AGENT_BASE_IMAGE       = AGENT_BASE_IMAGE
    HERMES_AGENT_IMAGE     = pins.manual.hermes_agent.ref
    HERMES_WORKSPACE_IMAGE = pins.manual.hermes_workspace.ref
    HERMES_VERSION         = pins.manual.hermes.version
    HERMES_PYTHON_VERSION  = pins.managed.python.version

    # Derived from the same value that feeds AGENT_BASE_IMAGE, so the recorded
    # base digest cannot disagree with what was actually built against.
    AGENT_BASE_DIGEST = AGENT_BASE_IMAGE

    SOURCE_COMMIT = SOURCE_COMMIT
    BUILD_DATE    = BUILD_DATE
    BUILD_VERSION = BUILD_VERSION
  }
}
