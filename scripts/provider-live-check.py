#!/usr/bin/env python3
"""Tiny live Provider check for OpenDeepSeek.

This intentionally sends one minimal chat completion request. Use it before
recording or publishing when you need to distinguish "service is broken" from
"the configured API key/base URL/model is invalid".
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / ".env"


def read_env() -> dict[str, str]:
    values: dict[str, str] = {}
    if ENV_FILE.exists():
        for raw in ENV_FILE.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip("\"'")
    values.update({
        k: v
        for k, v in os.environ.items()
        if k.startswith(("OPDS_", "DEEPSEEK_", "OPENROUTER_", "CUSTOM_MODEL_", "OPENAI_"))
    })
    return values


def ensure_v1(url: str) -> str:
    value = url.strip().rstrip("/")
    if not value:
        return value
    if value.endswith("/chat/completions"):
        return value[: -len("/chat/completions")].rstrip("/")
    if value.endswith("/v1"):
        return value
    return value + "/v1"


def redact(value: str) -> str:
    if not value:
        return "<empty>"
    if len(value) <= 10:
        return value[:2] + "***"
    return value[:6] + "***" + value[-4:]


def main() -> int:
    env = read_env()
    provider = (env.get("OPDS_LLM_PROVIDER") or "deepseek").strip().lower()
    base_url = (
        env.get("OPDS_LLM_BASE_URL")
        or env.get("DEEPSEEK_API_BASE")
        or ("https://openrouter.ai/api" if provider == "openrouter" else "https://api.deepseek.com")
    )
    if provider == "deepseek":
        key = env.get("OPDS_LLM_API_KEY") or env.get("DEEPSEEK_API_KEY", "")
        model = env.get("OPDS_LLM_MODEL") or env.get("DEFAULT_MODEL") or "deepseek-v4-flash"
    elif provider == "openrouter":
        key = env.get("OPDS_LLM_API_KEY") or env.get("OPENROUTER_API_KEY", "")
        model = env.get("OPDS_LLM_MODEL") or env.get("OPENROUTER_MODEL", "")
    else:
        key = (
            env.get("OPDS_LLM_API_KEY")
            or env.get("OPDS_CUSTOM_LLM_API_KEY")
            or env.get("CUSTOM_MODEL_API_KEY")
            or env.get("OPENAI_API_KEY")
            or ""
        )
        model = env.get("OPDS_LLM_MODEL") or env.get("OPDS_CUSTOM_LLM_MODEL") or env.get("CUSTOM_MODEL_NAME", "")

    if not base_url or not model:
        print("FAIL provider config missing base_url or model")
        print(f"provider={provider} base_url={base_url or '<empty>'} model={model or '<empty>'}")
        return 1

    host = ensure_v1(base_url)
    is_local = host.startswith(("http://localhost", "http://127.0.0.1", "http://host.docker.internal"))
    if not key and not is_local:
        print("FAIL provider API key missing")
        print(f"provider={provider} base_url={host} model={model}")
        return 1

    payload = {
        "model": model,
        "stream": False,
        "messages": [{"role": "user", "content": "只回复 OK"}],
        "max_tokens": 8,
    }
    headers = {"Content-Type": "application/json"}
    if key:
        headers["Authorization"] = f"Bearer {key}"
    req = urllib.request.Request(
        host.rstrip("/") + "/chat/completions",
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers=headers,
    )
    print(f"Provider live check: provider={provider} model={model} base_url={host} key={redact(key)}")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"FAIL HTTP {exc.code}")
        print(body[:700])
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"FAIL {type(exc).__name__}: {exc}")
        return 1

    try:
        data = json.loads(body)
        text = data["choices"][0]["message"].get("content") or data["choices"][0]["message"].get("reasoning_content")
    except Exception:
        text = ""
    if not text or not str(text).strip():
        print("FAIL provider returned no message content")
        print(body[:700])
        return 1
    print("PASS provider returned content")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
