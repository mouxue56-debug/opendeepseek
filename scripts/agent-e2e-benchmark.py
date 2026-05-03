#!/usr/bin/env python3
"""
OpenDeepSeek Agent E2E Benchmark

Runs 10 fresh Hermes API conversations, 3 turns each, using the cheap default
model path (deepseek-v4-flash unless .env overrides DEFAULT_MODEL).

The benchmark avoids printing private local filenames. It only checks that
/host exists and writes harmless artifacts under:
  /host/OpenDeepSeek-Outputs/benchmark
"""

from __future__ import annotations

import json
import os
import statistics
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / ".env"
API_URL = os.environ.get("HERMES_API_URL", "http://localhost:8642/v1/chat/completions")
MODEL = os.environ.get("BENCH_MODEL", "hermes-agent")
STAMP = time.strftime("%Y%m%d-%H%M%S")
REPORT_DIR = ROOT / "benchmark-results"
REPORT_PATH = REPORT_DIR / f"agent-e2e-{STAMP}.json"


def read_env() -> dict[str, str]:
    values: dict[str, str] = {}
    if ENV_FILE.exists():
        for raw in ENV_FILE.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip("\"'")
    values.update({k: v for k, v in os.environ.items() if k.startswith(("HERMES_", "DEFAULT_"))})
    return values


ENV = read_env()
HERMES_KEY = ENV.get("HERMES_API_KEY", "")
DEFAULT_MODEL = ENV.get("DEFAULT_MODEL", "deepseek-v4-flash")


SCENARIOS = [
    {
        "name": "identity_and_instruction_following",
        "turns": [
            "用一句中文介绍你是什么，不超过 30 个字。",
            "继续上一轮，只用三个中文短语概括你的能力。",
            "只输出 BENCH_OK。",
        ],
        "expect": ["BENCH_OK"],
    },
    {
        "name": "conversation_context",
        "turns": [
            "本轮测试的临时代号是「紫藤-17」。只需要回复：已记录。",
            "不要看外部资料，回答刚才的临时代号是什么？",
            "只输出 BENCH_OK 和这个代号。",
        ],
        "expect": ["BENCH_OK", "紫藤-17"],
    },
    {
        "name": "host_mount_check",
        "turns": [
            "请实际使用 terminal 工具检查 /host 是否存在。不要列任何文件名；存在只回答 HOST_READY，否则回答 HOST_MISSING。",
            "请实际使用 terminal 工具检查 /host/Desktop 是否存在。不要列任何文件名；存在只回答 DESKTOP_READY，否则回答 DESKTOP_MISSING。",
            "请创建 /host/OpenDeepSeek-Outputs/benchmark/session03.txt，内容只写 BENCH_FILE_OK，然后回复 BENCH_OK。",
        ],
        "expect": ["BENCH_OK"],
        "artifact": "/host/OpenDeepSeek-Outputs/benchmark/session03.txt",
    },
    {
        "name": "single_file_website",
        "turns": [
            "请创建目录 /host/OpenDeepSeek-Outputs/benchmark/site-demo。",
            "请在该目录写一个单文件 index.html，主题是「DeepSeek V4 + Hermes 真 Agent」，手机端好看，内容简洁。",
            "请确认文件已写入，只输出 BENCH_OK 和文件路径。",
        ],
        "expect": ["BENCH_OK", "index.html"],
        "artifact": "/host/OpenDeepSeek-Outputs/benchmark/site-demo/index.html",
    },
    {
        "name": "weekly_report_artifact",
        "turns": [
            "请准备生成一份中文周报草稿，主题：OpenDeepSeek 发布前冲刺。",
            "请写入 /host/OpenDeepSeek-Outputs/benchmark/weekly-report.md，包含本周进展、风险、下周计划。",
            "只输出 BENCH_OK 和文件路径。",
        ],
        "expect": ["BENCH_OK", "weekly-report.md"],
        "artifact": "/host/OpenDeepSeek-Outputs/benchmark/weekly-report.md",
    },
    {
        "name": "video_script_artifact",
        "turns": [
            "请把这个观点整理成短视频逻辑：DeepSeek 不该只是聊天框，接上 Hermes 才能真做事。",
            "请写入 /host/OpenDeepSeek-Outputs/benchmark/video-script.md，包含开头钩子、痛点、演示、结尾号召。",
            "只输出 BENCH_OK 和文件路径。",
        ],
        "expect": ["BENCH_OK", "video-script.md"],
        "artifact": "/host/OpenDeepSeek-Outputs/benchmark/video-script.md",
    },
    {
        "name": "terminal_python_execution",
        "turns": [
            "请实际使用 terminal 工具运行 Python 计算 sum(range(1, 11))。",
            "上一轮计算结果是多少？只回答数字。",
            "只输出 BENCH_OK 和这个数字。",
        ],
        "expect": ["BENCH_OK", "55"],
    },
    {
        "name": "safe_desktop_plan",
        "turns": [
            "请检查 /host/Desktop 是否存在，但不要列文件名、不要移动文件。",
            "请生成一个桌面整理方案，不执行移动、删除、改名。",
            "请把方案写到 /host/OpenDeepSeek-Outputs/benchmark/desktop-plan.md，并只输出 BENCH_OK。",
        ],
        "expect": ["BENCH_OK"],
        "artifact": "/host/OpenDeepSeek-Outputs/benchmark/desktop-plan.md",
    },
    {
        "name": "cron_capability_without_creation",
        "turns": [
            "请说明你是否具备 Hermes Cron 定时任务能力，限制 50 字内。",
            "不要创建任务。请给一个用户可以复制的提醒命令示例。",
            "只输出 BENCH_OK。",
        ],
        "expect": ["BENCH_OK"],
    },
    {
        "name": "preference_memory_prompt",
        "turns": [
            "本轮测试里假设用户偏好：中文、直接、少废话。只回复已收到。",
            "基于这个偏好，给 OpenDeepSeek 写一句产品标语。",
            "只输出 BENCH_OK。",
        ],
        "expect": ["BENCH_OK"],
    },
]


def post_chat(session_id: str, user_message: str, timeout: int = 240) -> tuple[dict, float, str]:
    body = {
        "model": MODEL,
        "messages": [{"role": "user", "content": user_message}],
        "temperature": 0.2,
        "max_tokens": 700,
    }
    req = urllib.request.Request(
        API_URL,
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {HERMES_KEY}",
            "Content-Type": "application/json",
            "X-Hermes-Session-Id": session_id,
        },
        method="POST",
    )
    start = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            elapsed = time.perf_counter() - start
            return json.loads(raw), elapsed, ""
    except urllib.error.HTTPError as exc:
        elapsed = time.perf_counter() - start
        raw = exc.read().decode("utf-8", errors="replace")
        return {}, elapsed, f"HTTP {exc.code}: {raw[:500]}"
    except Exception as exc:  # noqa: BLE001
        elapsed = time.perf_counter() - start
        return {}, elapsed, repr(exc)


def content_of(resp: dict) -> str:
    try:
        return resp["choices"][0]["message"].get("content") or ""
    except Exception:
        return ""


def usage_of(resp: dict) -> dict:
    usage = resp.get("usage") if isinstance(resp, dict) else None
    return usage if isinstance(usage, dict) else {}


def artifact_exists(container_path: str) -> bool:
    if not container_path.startswith("/host/"):
        return False
    host_root = ENV.get("HERMES_HOST_DIR") or str(Path.home())
    local_path = Path(host_root) / container_path.removeprefix("/host/")
    return local_path.exists()


def main() -> int:
    if not HERMES_KEY:
        print("ERR: HERMES_API_KEY missing. Run ./setup.sh --web first.", file=sys.stderr)
        return 1

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    print("OpenDeepSeek Agent E2E Benchmark")
    print(f"  api model:      {MODEL}")
    print(f"  llm default:    {DEFAULT_MODEL}")
    print(f"  conversations:  {len(SCENARIOS)}")
    print(f"  turns:          {len(SCENARIOS) * 3}")
    print("")

    results = []
    all_latencies = []
    total_prompt_tokens = 0
    total_completion_tokens = 0

    for idx, scenario in enumerate(SCENARIOS, start=1):
        session_id = f"ods-bench-{STAMP}-{idx:02d}"
        turn_results = []
        scenario_text = ""
        scenario_ok = True
        print(f"[{idx:02d}/10] {scenario['name']}")

        for turn_idx, prompt in enumerate(scenario["turns"], start=1):
            resp, latency, error = post_chat(session_id, prompt)
            content = content_of(resp)
            usage = usage_of(resp)
            all_latencies.append(latency)
            total_prompt_tokens += int(usage.get("prompt_tokens") or 0)
            total_completion_tokens += int(usage.get("completion_tokens") or 0)
            scenario_text += "\n" + content
            if error or not content:
                scenario_ok = False
            turn_results.append({
                "turn": turn_idx,
                "latency_sec": round(latency, 3),
                "ok": not error and bool(content),
                "error": error,
                "usage": usage,
                "content_preview": content[:240],
            })
            print(f"  turn {turn_idx}: {latency:.1f}s {'OK' if not error and content else 'FAIL'}")

        missing = [needle for needle in scenario.get("expect", []) if needle not in scenario_text]
        if missing:
            scenario_ok = False
        artifact = scenario.get("artifact")
        artifact_ok = artifact_exists(artifact) if artifact else None
        if artifact and not artifact_ok:
            scenario_ok = False

        print(f"  result: {'PASS' if scenario_ok else 'FAIL'}")
        if artifact:
            print(f"  artifact: {'OK' if artifact_ok else 'MISSING'} {artifact}")

        results.append({
            "name": scenario["name"],
            "session_id": session_id,
            "ok": scenario_ok,
            "missing_expectations": missing,
            "artifact": artifact,
            "artifact_ok": artifact_ok,
            "turns": turn_results,
        })

    passed = sum(1 for r in results if r["ok"])
    failed = len(results) - passed
    avg_latency = statistics.mean(all_latencies) if all_latencies else 0
    p95_latency = statistics.quantiles(all_latencies, n=20)[18] if len(all_latencies) >= 20 else max(all_latencies or [0])
    total_tokens = total_prompt_tokens + total_completion_tokens

    report = {
        "stamp": STAMP,
        "api_url": API_URL,
        "api_model": MODEL,
        "default_model": DEFAULT_MODEL,
        "summary": {
            "conversations": len(SCENARIOS),
            "turns": len(SCENARIOS) * 3,
            "passed": passed,
            "failed": failed,
            "avg_latency_sec": round(avg_latency, 3),
            "p95_latency_sec": round(p95_latency, 3),
            "prompt_tokens": total_prompt_tokens,
            "completion_tokens": total_completion_tokens,
            "total_tokens": total_tokens,
        },
        "results": results,
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print("")
    print("Summary")
    print(f"  passed:      {passed}/{len(SCENARIOS)}")
    print(f"  failed:      {failed}")
    print(f"  avg latency: {avg_latency:.1f}s")
    print(f"  p95 latency: {p95_latency:.1f}s")
    print(f"  tokens:      {total_tokens} (prompt {total_prompt_tokens}, completion {total_completion_tokens})")
    print(f"  report:      {REPORT_PATH}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
