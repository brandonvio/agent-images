# Single source of truth for agent-base build arguments.
#
# Every pinned version and checksum is read out of pins.json (raw downloads and
# base-image digests) and package.json (the npm CLI set), so a pin bump is a
# one-file diff and CI and local builds produce the same bytes.

# buildx bake has no file() function, so pins.json and package.json are handed
# in through the environment. `make build` and every workflow step do this the
# same way:  PINS_JSON="$(cat pins.json)" CLIS_JSON="$(cat package.json)" ...
variable "PINS_JSON" {
  default = "{}"
}

variable "CLIS_JSON" {
  default = "{}"
}

pins = jsondecode(PINS_JSON)
clis = jsondecode(CLIS_JSON)

variable "IMAGE" {
  default = "brandonvio/agent-base"
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
  targets = ["agent-base"]
}

target "agent-base" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = ["${IMAGE}:${TAG}"]
  platforms  = ["linux/amd64"]

  args = {
    UBUNTU_IMAGE = pins.managed.ubuntu.ref

    UV_VERSION      = pins.managed.uv.version
    UV_SHA256_AMD64 = pins.managed.uv.sha256.amd64
    UV_SHA256_ARM64 = pins.managed.uv.sha256.arm64

    PYTHON_VERSION = pins.managed.python.version

    NVM_VERSION       = pins.managed.nvm.version
    NVM_COMMIT        = pins.managed.nvm.commit
    NODE_VERSION      = pins.managed.node.version
    NODE_SHA256_AMD64 = pins.managed.node.sha256.amd64
    NODE_SHA256_ARM64 = pins.managed.node.sha256.arm64

    GO_VERSION      = pins.managed.go.version
    GO_SHA256_AMD64 = pins.managed.go.sha256.amd64
    GO_SHA256_ARM64 = pins.managed.go.sha256.arm64

    KUBECTL_VERSION      = pins.managed.kubectl.version
    KUBECTL_SHA256_AMD64 = pins.managed.kubectl.sha256.amd64
    KUBECTL_SHA256_ARM64 = pins.managed.kubectl.sha256.arm64

    ARGOCD_VERSION      = pins.managed.argocd.version
    ARGOCD_SHA256_AMD64 = pins.managed.argocd.sha256.amd64
    ARGOCD_SHA256_ARM64 = pins.managed.argocd.sha256.arm64

    RUST_VERSION = pins.managed.rust.version

    OH_MY_ZSH_COMMIT               = pins.managed.oh_my_zsh.commit
    ZSH_AUTOSUGGESTIONS_COMMIT     = pins.managed.zsh_autosuggestions.commit
    ZSH_SYNTAX_HIGHLIGHTING_COMMIT = pins.managed.zsh_syntax_highlighting.commit
    ZSH_COMPLETIONS_COMMIT         = pins.managed.zsh_completions.commit

    CLAUDE_CODE_VERSION = clis.dependencies["@anthropic-ai/claude-code"]
    CODEX_VERSION       = clis.dependencies["@openai/codex"]

    SOURCE_COMMIT = SOURCE_COMMIT
    BUILD_DATE    = BUILD_DATE
    BUILD_VERSION = BUILD_VERSION
  }
}
