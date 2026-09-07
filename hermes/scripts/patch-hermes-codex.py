#!/usr/bin/env python3
"""Apply Hermes openai-codex compatibility hotfixes.

Hermes v2026.5.29.2 still ships OpenAI SDK code that assumes
response.completed.response.output is iterable. The ChatGPT Codex backend can
return output=null for gpt-5.5 terminal stream events, which leaves Hermes
stuck or crashes stream parsing. Keep this patch small and idempotent so it can
be removed once upstream images contain the durable fix.
"""

from __future__ import annotations

from pathlib import Path


def patch_file(path: Path, old: str, new: str, label: str) -> None:
    if not path.exists():
        raise SystemExit(f"{label}: missing {path}")

    text = path.read_text()
    if new in text:
        print(f"{label}: already patched")
        return
    if old not in text:
        raise SystemExit(f"{label}: target text not found in {path}")

    path.write_text(text.replace(old, new, 1))
    print(f"{label}: patched {path}")


def main() -> None:
    sdk_matches = sorted(
        Path("/opt/hermes/.venv/lib").glob(
            "python*/site-packages/openai/lib/_parsing/_responses.py"
        )
    )
    if not sdk_matches:
        raise SystemExit("openai SDK parser file not found under /opt/hermes/.venv/lib")

    patch_file(
        sdk_matches[0],
        "for output in response.output:",
        "for output in (response.output or []):",
        "openai-sdk-null-output",
    )

    transport_path = Path("/opt/hermes/agent/transports/codex.py")
    if transport_path.exists():
        old = (
            '            "tools": response_tools,\n'
            '            "store": False,\n'
            "        }\n"
            "        if response_tools:\n"
            '            kwargs["tool_choice"] = "auto"\n'
            '            kwargs["parallel_tool_calls"] = True'
        )
        new = (
            '            "store": False,\n'
            "        }\n"
            "        if response_tools:\n"
            '            kwargs["tools"] = response_tools\n'
            '            kwargs["tool_choice"] = "auto"\n'
            '            kwargs["parallel_tool_calls"] = True'
        )
        text = transport_path.read_text()
        if 'kwargs["tools"] = response_tools' in text:
            print("codex-transport-tools-none: already patched")
        elif old in text:
            transport_path.write_text(text.replace(old, new, 1))
            print(f"codex-transport-tools-none: patched {transport_path}")
        else:
            print("codex-transport-tools-none: skipped, source shape differs")


if __name__ == "__main__":
    main()
