#!/usr/bin/env python3
"""Offline routing regression benchmark for OpenDeepSeek Smart Bridge.

This script imports the bridge routing function and validates labeled prompts
without calling DeepSeek, Hermes, Open WebUI, or Docker.
"""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bridge"))

from hermes_image_bridge import route_prompt_for_testing  # noqa: E402


CASES: list[tuple[str, str, str, int, bool]] = [
    ("你好，用一句话介绍你自己", "deepseek-lite", "simple-chat", 0, False),
    ("解释一下什么是 API", "deepseek-lite", "simple-chat", 0, False),
    ("把这段话翻译成英文：我今天很忙", "deepseek-lite", "simple-chat", 0, False),
    ("写一个三句中文小红书标题", "deepseek-lite", "simple-chat", 0, False),
    ("fast: 总结一下这句话", "deepseek-lite", "forced-fast", 0, False),
    ("请查看 /host/Desktop 有什么", "hermes", "host-path", 0, False),
    ("请读取 /Users/lauralyu/Desktop/test.txt", "hermes", "host-path", 0, False),
    ("帮我看看 ~/Downloads 里有什么", "hermes", "host-path", 0, False),
    ("整理我的桌面但不要删除文件", "hermes", "local-files", 0, False),
    ("列出 Documents 里的文件类型", "hermes", "local-files", 0, False),
    ("查看下载目录最近 30 天文件", "hermes", "local-files", 0, False),
    ("请生成一个网页 index.html", "hermes", "artifact", 0, False),
    ("创建一个网站保存到输出目录", "hermes", "artifact", 0, False),
    ("把周报写入 /host/OpenDeepSeek-Outputs/a.md", "hermes", "host-path", 0, False),
    ("保存到 OpenDeepSeek-Outputs", "hermes", "artifact", 0, False),
    ("实际创建一个报告文件", "hermes", "artifact", 0, False),
    ("提醒我 10 分钟后喝水", "hermes", "schedule", 0, False),
    ("创建一个定时任务", "hermes", "schedule", 0, False),
    ("用 cron 工具创建提醒", "hermes", "schedule", 0, False),
    ("记住我喜欢中文直接回答", "hermes", "memory", 0, False),
    ("长期记忆一下我的项目偏好", "hermes", "memory", 0, False),
    ("你记得我之前说过什么吗", "hermes", "memory", 0, False),
    ("运行 python 计算 1+1", "hermes", "tools", 0, False),
    ("用 terminal 检查当前目录", "hermes", "tools", 0, False),
    ("执行 bash 命令 pwd", "hermes", "tools", 0, False),
    ("调用工具帮我完成", "hermes", "tools", 0, False),
    ("Hermes agent 模式处理这个任务", "hermes", "tools", 0, False),
    ("上传图片后做 OCR", "hermes", "image", 0, False),
    ("根据这张截图做网页", "hermes", "image", 0, False),
    ("图片路径在哪里", "hermes", "image", 0, False),
    ("给我今天 AI 圈早报", "hermes", "realtime", 0, False),
    ("整理最新大模型新闻", "hermes", "realtime", 0, False),
    ("搜一下 OpenWebUI 最新文档", "hermes", "realtime", 0, False),
    ("联网查一下这个库怎么用", "hermes", "realtime", 0, False),
    ("全网调研 Hermes Agent", "hermes", "realtime", 0, False),
    ("/agent 用工具创建文件", "hermes", "forced-agent", 0, False),
    ("agent: 看看桌面", "hermes", "forced-agent", 0, False),
    ("hermes: 创建提醒", "hermes", "forced-agent", 0, False),
    ("OpenWebUI 原生 search_web 工具请求", "deepseek-lite", "openwebui-native-tools", 0, True),
    ("用知识库回答这个问题", "deepseek-lite", "openwebui-native-tools", 0, True),
    ("普通聊天但带 OpenWebUI tools", "deepseek-lite", "openwebui-native-tools", 0, True),
    ("请总结这张图片", "hermes", "image", 1, False),
    ("有图片附件的普通描述", "hermes", "image", 2, False),
    ("路由关闭时随便问", "hermes", "routing-disabled", 0, False),
    ("没有 DeepSeek key 时随便问", "hermes", "missing-deepseek-key", 0, False),
    ("解释什么是 Docker Compose", "deepseek-lite", "simple-chat", 0, False),
    ("给我一个学习计划，不需要保存文件", "deepseek-lite", "simple-chat", 0, False),
    ("写一段视频开头文案", "deepseek-lite", "simple-chat", 0, False),
    ("把这个也做成网站形式来展现", "hermes", "artifact", 0, False),
    ("请不要只解释，要实际使用工具", "hermes", "tools", 0, False),
]


def main() -> int:
    passed = 0
    failed = []

    for index, (prompt, expected_route, expected_reason_prefix, image_count, has_tools) in enumerate(CASES, 1):
        lightweight = expected_reason_prefix != "routing-disabled"
        has_key = expected_reason_prefix != "missing-deepseek-key"
        result = route_prompt_for_testing(
            prompt,
            image_count=image_count,
            has_tools=has_tools,
            lightweight=lightweight,
            has_deepseek_key=has_key,
        )
        route_ok = result["route"] == expected_route
        reason_ok = result["reason"].startswith(expected_reason_prefix)
        if route_ok and reason_ok:
            passed += 1
            continue
        failed.append((index, prompt, expected_route, expected_reason_prefix, result))

    total = len(CASES)
    f1 = passed / total
    print("OpenDeepSeek offline routing benchmark")
    print(f"  total: {total}")
    print(f"  pass:  {passed}")
    print(f"  F1:    {f1:.2f}")
    if failed:
        print("")
        print("Failures:")
        for index, prompt, expected_route, expected_reason, result in failed:
            print(f"- #{index}: {prompt}")
            print(f"  expected: route={expected_route} reason~={expected_reason}")
            print(f"  actual:   route={result['route']} reason={result['reason']}")
        return 1
    print("PASS: F1=1.00")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
