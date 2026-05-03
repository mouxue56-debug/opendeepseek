"""
title: Hermes Agent 工具集
description: 让 Open WebUI 用户能用上 Hermes Agent 的 Cron / Memory / Subagent 等高级能力
author: OpenDeepSeek
version: 1.0.0
"""
import os
import json
import requests
from pydantic import BaseModel, Field
from typing import Optional, List


class Tools:
    class Valves(BaseModel):
        HERMES_API_URL: str = Field(
            default="http://hermes:8642/v1",
            description="Hermes API 地址（容器内是 hermes:8642，开发时可改为 http://localhost:8642/v1）",
        )
        HERMES_API_KEY: str = Field(
            default="",
            description="Hermes API Key（在 setup.sh 中自动生成，对应 .env 的 HERMES_API_KEY）",
        )
        DEFAULT_TIMEOUT: int = Field(
            default=120,
            description="调用 Hermes 的超时时间（秒）",
        )

    def __init__(self):
        self.valves = self.Valves()

    def _call_hermes(self, user_prompt: str, max_tokens: int = 800) -> str:
        """内部辅助：调用 Hermes /v1/chat/completions 让它 Agent loop 处理"""
        api_key = self.valves.HERMES_API_KEY or os.environ.get("HERMES_API_KEY", "")
        if not api_key:
            return "❌ HERMES_API_KEY 未配置，请在 Open WebUI Admin → Tools → Hermes Agent → Valves 中填入"
        try:
            r = requests.post(
                f"{self.valves.HERMES_API_URL}/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "hermes-agent",
                    "messages": [{"role": "user", "content": user_prompt}],
                    "max_tokens": max_tokens,
                },
                timeout=self.valves.DEFAULT_TIMEOUT,
            )
            r.raise_for_status()
            data = r.json()
            msg = data.get("choices", [{}])[0].get("message", {})
            return msg.get("content") or msg.get("reasoning_content") or "(Hermes 返回空内容)"
        except requests.exceptions.Timeout:
            return f"❌ 调用 Hermes 超时（{self.valves.DEFAULT_TIMEOUT} 秒），任务可能仍在后台执行"
        except Exception as e:
            return f"❌ 调用 Hermes 失败: {e}"

    # ─── Tool 1: 定时任务 ─────────────────────────────────────────────
    def schedule_task(
        self,
        when: str,
        what: str,
        deliver_to: str = "本对话",
    ) -> str:
        """
        创建定时任务。当用户说"明天9点提醒我..."、"半小时后..."、"每周一..."时调用。
        Hermes 内部 cron skill 会自动解析时间并创建任务。

        :param when: 时间表达式，例如 "30 分钟后"、"明天上午 9 点"、"每周一上午 10 点"
        :param what: 任务内容描述
        :param deliver_to: 结果投递通道，默认 "本对话"
        :return: Hermes 返回的任务创建结果（含任务 ID + 执行时间）
        """
        prompt = (
            f"请用 cron 工具创建一个定时任务：\n"
            f"时间：{when}\n"
            f"任务：{what}\n"
            f"结果投递：{deliver_to}\n"
            f"请实际调用 cron 工具创建（不要只口头回复）。"
        )
        return self._call_hermes(prompt, max_tokens=600)

    # ─── Tool 2: 写入长期记忆 ──────────────────────────────────────────
    def save_memory(
        self,
        fact: str,
        category: str = "general",
    ) -> str:
        """
        把一条事实写入 Hermes 长期记忆。当用户说"记住..."、"我喜欢..."、"以后..."时调用。
        Hermes Memory 跨会话持久化（写入 MEMORY.md / USER.md）。

        :param fact: 要记住的事实
        :param category: 分类标签，例如 "preference"、"profile"、"general"
        :return: 写入结果
        """
        prompt = (
            f"请用 memory 工具记住下面这条信息：\n"
            f"内容：{fact}\n"
            f"分类：{category}\n"
            f"请实际调用 memory_save 工具写入持久化记忆（不要只口头说记住了）。"
        )
        return self._call_hermes(prompt, max_tokens=400)

    # ─── Tool 3: 查询长期记忆 ──────────────────────────────────────────
    def recall_memory(
        self,
        query: str = "",
    ) -> str:
        """
        从 Hermes 长期记忆中查询历史事实。当用户问"你记得我..."、"我之前说过..."时调用。

        :param query: 查询关键词（可选，留空=查全部相关记忆）
        :return: 相关记忆内容
        """
        if query:
            prompt = f"请查询 memory 里关于「{query}」的内容，并完整返回找到的所有相关记忆。"
        else:
            prompt = "请列出 memory 中所有关于用户的事实（user profile + general memory）。"
        return self._call_hermes(prompt, max_tokens=600)

    # ─── Tool 4: 并行子任务 ────────────────────────────────────────────
    def parallel_research(
        self,
        tasks: List[str],
        max_parallel: int = 3,
    ) -> str:
        """
        派 N 个 subagent 并行执行任务。当用户说"同时帮我..."、"对比这几个..."、"分别看看..."时调用。

        :param tasks: 任务列表（每个元素是一个独立子任务的 prompt）
        :param max_parallel: 最大并行数（默认 3）
        :return: 所有 subagent 的结果汇总
        """
        task_list = "\n".join(f"{i + 1}. {t}" for i, t in enumerate(tasks))
        prompt = (
            f"请用 delegate_task / subagent 工具并行执行以下 {len(tasks)} 个任务"
            f"（最多 {max_parallel} 个并发）：\n\n{task_list}\n\n"
            "等所有 subagent 完成后，给我一个对比总结。"
        )
        return self._call_hermes(prompt, max_tokens=1500)

    # ─── Tool 5: 文件读写 ─────────────────────────────────────────────
    def file_operations(
        self,
        action: str,
        path: str,
        content: str = "",
    ) -> str:
        """
        在 Hermes 沙盒环境中读写文件。当用户提到具体文件路径需要读/写/列时调用。

        :param action: 操作类型，必须是 "read" / "write" / "list" 之一
        :param path: 文件或目录路径
        :param content: write 时的文件内容（read/list 时忽略）
        :return: 操作结果或文件内容
        """
        action_lower = action.strip().lower()
        if action_lower == "read":
            prompt = f"请用 file 或 terminal 工具读取文件 `{path}` 的全部内容并返回。"
        elif action_lower == "write":
            prompt = (
                f"请把以下内容用 file 工具写入文件 `{path}`：\n\n"
                f"```\n{content}\n```\n\n"
                f"请实际写入（不要只口头说写了）。"
            )
        elif action_lower == "list":
            prompt = f"请用 terminal 工具列出目录 `{path}` 下的所有文件（ls -la）。"
        else:
            return f"❌ 不支持的 action: {action}（必须是 read / write / list）"
        return self._call_hermes(prompt, max_tokens=1000)

    # ─── Tool 6: 联网搜索 ─────────────────────────────────────────────
    def web_search(
        self,
        query: str,
        num_results: int = 5,
    ) -> str:
        """
        通过 Hermes 的 web_search skill 搜索网络。当用户问"今天..."、"现在..."、"查一下..."时调用。

        :param query: 搜索关键词
        :param num_results: 返回结果数量（默认 5）
        :return: 搜索结果摘要
        """
        prompt = (
            f"请用 web_search 工具搜索：「{query}」，"
            f"要 {num_results} 条结果，给我每条的标题 + 链接 + 摘要。"
        )
        return self._call_hermes(prompt, max_tokens=1500)
