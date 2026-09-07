#!/usr/bin/env python3
"""validate-pins — check the shape of every pins.json before anything builds.

The pin files are written by an agent rather than by a script with fixed
control flow, so the shape of what it wrote is checked mechanically: no key
silently dropped, every version non-empty and not a floating word, one 64-hex
sha256 per supported architecture for every raw download, and an ``@sha256:``
on every base-image ref.

A malformed pin file must fail here — not forty minutes into a build, and never
after publish.

Usage:
    scripts/validate-pins.py                 # validate every image's pins.json
    scripts/validate-pins.py --verify-hashes # additionally download each
                                             # pinned artifact and check its
                                             # sha256 against the recorded one
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parent.parent

HEX64 = re.compile(r"^[0-9a-f]{64}$")
FLOATING = {"latest", "stable", "current", "head", "main", "master", ""}

# What every image's pins.json must still contain. A key silently disappearing
# from a refresh is the failure this table exists to catch.
REQUIRED: dict[str, dict[str, list[str]]] = {
    "agent-base": {
        "managed": [
            "ubuntu",
            "node",
            "nvm",
            "python",
            "uv",
            "go",
            "rust",
            "kubectl",
            "argocd",
            "oh_my_zsh",
            "zsh_autosuggestions",
            "zsh_syntax_highlighting",
            "zsh_completions",
        ],
        "manual": [],
    },
    "hermes": {
        "managed": ["python"],
        "manual": ["hermes", "hermes_agent", "hermes_workspace"],
    },
    "openclaw": {"managed": [], "manual": ["openclaw"]},
    "cicd-runner": {
        "managed": ["docker_dind", "runner"],
        "manual": [],
    },
    "gpu-enabled": {"managed": ["cuda", "uv"], "manual": []},
}

# Raw downloads: which architectures each must carry a sha256 for.
ARCHES: dict[tuple[str, str], list[str]] = {
    ("agent-base", "node"): ["amd64", "arm64"],
    ("agent-base", "uv"): ["amd64", "arm64"],
    ("agent-base", "go"): ["amd64", "arm64"],
    ("agent-base", "kubectl"): ["amd64", "arm64"],
    ("agent-base", "argocd"): ["amd64", "arm64"],
    ("cicd-runner", "runner"): ["amd64"],
}

# How to rebuild each raw download's URL, for --verify-hashes. An entry that
# records its own per-arch `url` map in pins.json needs no template here.
URLS: dict[tuple[str, str], str] = {
    ("agent-base", "node"): (
        "https://nodejs.org/dist/v{version}/node-v{version}-linux-{nodearch}.tar.xz"
    ),
    ("agent-base", "uv"): (
        "https://github.com/astral-sh/uv/releases/download/{version}/uv-{uvtriple}.tar.gz"
    ),
    ("agent-base", "go"): "https://go.dev/dl/go{version}.linux-{arch}.tar.gz",
    ("agent-base", "kubectl"): (
        "https://dl.k8s.io/release/{version}/bin/linux/{arch}/kubectl"
    ),
    ("agent-base", "argocd"): (
        "https://github.com/argoproj/argo-cd/releases/download/{version}/argocd-linux-{arch}"
    ),
}

NODE_ARCH = {"amd64": "x64", "arm64": "arm64"}
UV_TRIPLE = {
    "amd64": "x86_64-unknown-linux-gnu",
    "arm64": "aarch64-unknown-linux-gnu",
}


class Failures(list[str]):
    def add(self, where: str, msg: str) -> None:
        self.append(f"{where}: {msg}")


def check_version(fail: Failures, where: str, value: object) -> None:
    if not isinstance(value, str) or value.strip().lower().lstrip("v") in FLOATING:
        fail.add(where, f"version is empty or floating: {value!r}")


def check_ref(fail: Failures, where: str, value: object) -> None:
    if not isinstance(value, str) or "@sha256:" not in value:
        fail.add(where, f"image ref is not digest-pinned: {value!r}")


def check_commit(fail: Failures, where: str, value: object) -> None:
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{40}", value):
        fail.add(where, f"commit is not a 40-hex SHA: {value!r}")


def validate(image: str, fail: Failures) -> dict[str, Any]:
    path = REPO / image / "pins.json"
    if not path.exists():
        fail.add(image, "pins.json is missing")
        return {}

    data = json.loads(path.read_text())
    for section in ("managed", "manual"):
        if section not in data or not isinstance(data[section], dict):
            fail.add(image, f"missing '{section}' section")

    for section, keys in REQUIRED[image].items():
        present = data.get(section, {})
        for key in keys:
            if key not in present:
                fail.add(f"{image}/{section}", f"required key dropped: {key}")

    for section in ("managed", "manual"):
        for key, entry in data.get(section, {}).items():
            where = f"{image}/{section}/{key}"
            if not isinstance(entry, dict):
                fail.add(where, "entry is not an object")
                continue

            if "ref" in entry:
                check_ref(fail, where, entry["ref"])
            if "version" in entry:
                check_version(fail, where, entry["version"])
            if "commit" in entry:
                check_commit(fail, where, entry["commit"])
            if not {"ref", "version", "commit"} & set(entry):
                fail.add(where, "entry records neither a ref, a version nor a commit")

            arches = ARCHES.get((image, key))
            if arches:
                shas = entry.get("sha256")
                if not isinstance(shas, dict):
                    fail.add(where, "raw download has no per-arch sha256 map")
                    continue
                for arch in arches:
                    if arch not in shas:
                        fail.add(where, f"missing sha256 for {arch}")
                    elif not HEX64.fullmatch(str(shas[arch])):
                        fail.add(where, f"sha256[{arch}] is not 64 hex characters")
                extra = set(shas) - set(arches)
                if extra:
                    fail.add(where, f"sha256 map has unsupported arches: {sorted(extra)}")
                if len(set(shas.values())) != len(shas):
                    fail.add(where, "the same sha256 is reused across architectures")

    return data


def verify_hashes(
    image: str,
    data: dict[str, Any],
    fail: Failures,
) -> None:
    for (img, key), arches in ARCHES.items():
        if img != image:
            continue
        entry = data.get("managed", {}).get(key)
        if not entry:
            continue
        template = URLS.get((img, key))
        for arch in arches:
            expected = entry["sha256"][arch]
            if template is None:
                url = entry["url"][arch]
            else:
                url = template.format(
                    version=entry["version"],
                    arch=arch,
                    nodearch=NODE_ARCH.get(arch, arch),
                    uvtriple=UV_TRIPLE.get(arch, arch),
                )
            digest = hashlib.sha256()
            with urllib.request.urlopen(url) as fh:  # noqa: S310 - fixed hosts
                for chunk in iter(lambda: fh.read(1 << 20), b""):
                    digest.update(chunk)
            actual = digest.hexdigest()
            where = f"{image}/managed/{key}[{arch}]"
            if actual != expected:
                fail.add(where, f"sha256 mismatch: recorded {expected}, actual {actual}")
            else:
                print(f"  verified {where}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--verify-hashes",
        action="store_true",
        help="download each pinned artifact and check its sha256",
    )
    args = parser.parse_args()

    fail = Failures()
    for image in REQUIRED:
        data = validate(image, fail)
        if args.verify_hashes and data:
            verify_hashes(image, data, fail)

    if fail:
        print("validate-pins: FAIL")
        for line in fail:
            print(f"  {line}")
        return 1

    print("validate-pins: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
