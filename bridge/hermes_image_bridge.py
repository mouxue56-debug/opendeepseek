#!/usr/bin/env python3
"""OpenAI-compatible smart bridge for OpenDeepSeek.

Open WebUI can send uploaded images as OpenAI-style `image_url` content parts.
DeepSeek V4 Flash is the reasoning backend here, but the DeepSeek text endpoint
rejects raw `image_url` parts. This bridge keeps the UX: users can upload images,
while the bridge extracts them locally, OCRs screenshots where possible, rewrites
the message into plain text, and forwards real tasks to Hermes.

It also routes simple chat directly to DeepSeek V4 Flash. That keeps normal Q&A
fast and cheap, while file tasks, images, reminders, memory, tools, and other
automation still go through Hermes Agent.
"""

from __future__ import annotations

import base64
import datetime as dt
import hashlib
import json
import mimetypes
import os
import re
import sys
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urljoin, urlparse
from urllib.parse import quote_plus

import requests

try:
    from PIL import Image
    import pytesseract
except ImportError:  # Local route tests do not need OCR dependencies.
    Image = None  # type: ignore[assignment]
    pytesseract = None  # type: ignore[assignment]


HERMES_BASE_URL = os.environ.get("HERMES_BASE_URL", "http://hermes:8642/v1").rstrip("/")
HERMES_API_KEY = os.environ.get("HERMES_API_KEY", "")
DEEPSEEK_BASE_URL = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1").rstrip("/")
DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")
DEFAULT_MODEL = os.environ.get("DEFAULT_MODEL", "deepseek-v4-flash")
ENABLE_LIGHTWEIGHT_ROUTING = os.environ.get("ENABLE_LIGHTWEIGHT_ROUTING", "true").lower() == "true"
HOST_ROOT = Path(os.environ.get("IMAGE_BRIDGE_HOST_ROOT", "/host"))
PUBLIC_HOST_PREFIX = os.environ.get("IMAGE_BRIDGE_PUBLIC_HOST_PREFIX", "/host").rstrip("/")
UPLOAD_ROOT = HOST_ROOT / "OpenDeepSeek-Inputs"
LISTEN_HOST = os.environ.get("IMAGE_BRIDGE_HOST", "0.0.0.0")
LISTEN_PORT = int(os.environ.get("IMAGE_BRIDGE_PORT", "8765"))
OCR_LANG = os.environ.get("IMAGE_BRIDGE_OCR_LANG", "chi_sim+eng")
REQUEST_TIMEOUT = int(os.environ.get("IMAGE_BRIDGE_TIMEOUT", "600"))
SHARED_MEMORY_PATH = Path(os.environ.get("OPDS_SHARED_MEMORY_PATH", str(HOST_ROOT / "OpenDeepSeek-Memory" / "profile.md")))
MEMORY_SNAPSHOT_MAX_CHARS = int(os.environ.get("OPDS_MEMORY_SNAPSHOT_MAX_CHARS", "4000"))
HOST_DISPLAY_PREFIX = os.environ.get("OPDS_HOST_DISPLAY_PREFIX", "").rstrip("/")
HERMES_AGENT_MAX_TOKENS = int(os.environ.get("HERMES_AGENT_MAX_TOKENS", "32768"))
HERMES_AGENT_STREAM = os.environ.get("HERMES_AGENT_STREAM", "false").lower() == "true"
HERMES_PROGRESS_STREAM = os.environ.get("HERMES_PROGRESS_STREAM", "true").lower() == "true"
HERMES_PROGRESS_MESSAGE = os.environ.get(
    "HERMES_PROGRESS_MESSAGE",
    "收到，这类请求需要 Hermes Agent 的工具/实时信息能力，我先切到 Agent 处理，请稍等…\n\n",
)
REALTIME_SEARCH_ENABLED = os.environ.get("OPDS_REALTIME_SEARCH_ENABLED", "true").lower() == "true"
REALTIME_SEARCH_URL = os.environ.get("OPDS_REALTIME_SEARCH_URL", "http://searxng:8080/search?q={query}&format=json")
REALTIME_SEARCH_TIMEOUT = float(os.environ.get("OPDS_REALTIME_SEARCH_TIMEOUT", "4"))
REALTIME_SEARCH_MAX_RESULTS = int(os.environ.get("OPDS_REALTIME_SEARCH_MAX_RESULTS", "6"))
DELEGATE_OPENWEBUI_NATIVE_TOOLS = os.environ.get("OPDS_DELEGATE_OPENWEBUI_NATIVE_TOOLS", "true").lower() == "true"


ROUTE_RULES: list[dict[str, Any]] = [
    {"label": "host-path", "summary": "本机文件任务", "patterns": [r"/host\b", r"/Users/", r"~/"]},
    {"label": "schedule", "summary": "提醒/定时任务", "patterns": [r"提醒我|定时|闹钟|计划任务|后台任务", r"\bcron\b"]},
    {"label": "memory", "summary": "长期记忆任务", "patterns": [r"记住|长期记忆|你记得|记忆|偏好", r"\bmemory\b"]},
    {"label": "image", "summary": "图片/OCR 任务", "patterns": [r"上传图片|截图|证据图|图片路径|OCR"]},
    {
        "label": "realtime",
        "summary": "实时资讯/资料整理任务",
        "patterns": [
            r"(?:今天|今日|最新|最近|近期|刚刚|实时|当前|现在).*(?:早报|日报|简报|新闻|资讯|动态|热点|信息|调研|整理)",
            r"(?:早报|日报|简报|新闻|资讯|动态|热点).*(?:今天|今日|最新|最近|近期|当前|现在|AI|大模型)",
            r"(?:搜索|搜一下|查一下|联网|网上|全网|资料|调研|信息整理|整理.*信息)",
            r"(?:AI圈|模型圈|大模型圈|科技圈).*(?:早报|日报|简报|新闻|资讯|动态|热点|整理)",
        ],
    },
    {
        "label": "tools",
        "summary": "工具/终端任务",
        "patterns": [
            r"\b(?:terminal|bash|shell|python|skill|subagent)\b",
            r"工具|调用|执行|运行|命令|终端|脚本",
            r"Hermes|真任务|Agent\s*(?:模式|路由|权限|能力)|切到.*Agent|用.*Agent",
        ],
    },
    {
        "label": "artifact",
        "summary": "文件/网页产出任务",
        "patterns": [
            r"创建.*(?:文件|目录|提醒|任务|网页|网站|PPT|幻灯片|报告|周报)",
            r"生成.*(?:文件|网页|网站|PPT|幻灯片|报告|周报|index\.html)",
            r"做成.*(?:网站|网页|页面|PPT|幻灯片)|网站形式|网页形式",
            r"保存到|写入|落盘|输出到|实际创建|实际使用",
        ],
    },
    {
        "label": "local-files",
        "summary": "本机文件任务",
        "patterns": [
            r"桌面|文件夹|目录|下载目录|Documents|Downloads|Desktop",
            r"查看.*文件|列出.*文件|整理.*文件|移动.*文件|删除.*文件|重命名",
        ],
    },
]

AGENT_PATTERNS = [pattern for rule in ROUTE_RULES for pattern in rule["patterns"]]

ARTIFACT_PATTERNS = [
    r"网页|网站|PPT|幻灯片|演示文稿|index\.html|HTML",
    r"生成.*(?:页面|落地页|官网|展示|deck|slides?)",
]

REALTIME_RESEARCH_PATTERNS = [
    r"(?:今天|今日|最新|最近|近期|刚刚|实时|当前|现在).*(?:早报|日报|简报|新闻|资讯|动态|热点|信息|调研|整理)",
    r"(?:早报|日报|简报|新闻|资讯|动态|热点).*(?:今天|今日|最新|最近|近期|当前|现在|AI|大模型)",
    r"(?:搜索|搜一下|查一下|联网|网上|全网|资料|调研|信息整理|整理.*信息)",
    r"(?:AI圈|模型圈|大模型圈|科技圈).*(?:早报|日报|简报|新闻|资讯|动态|热点|整理)",
]


def log(message: str) -> None:
    print(f"[image-bridge] {message}", file=sys.stderr, flush=True)


def log_event(event: str, **fields: Any) -> None:
    safe: dict[str, Any] = {
        "ts": dt.datetime.now(dt.UTC).isoformat(),
        "event": event,
    }
    for key, value in fields.items():
        if value is None:
            continue
        safe[key] = value if isinstance(value, (str, int, float, bool)) else str(value)
    print(f"[image-bridge-json] {json.dumps(safe, ensure_ascii=False)}", file=sys.stderr, flush=True)


def now_slug() -> str:
    return dt.datetime.now().strftime("%Y%m%d-%H%M%S")


def extension_for_mime(mime: str) -> str:
    if mime == "image/jpeg":
        return ".jpg"
    if mime == "image/png":
        return ".png"
    if mime == "image/webp":
        return ".webp"
    return mimetypes.guess_extension(mime) or ".img"


def public_path(path: Path) -> str:
    try:
        rel = path.relative_to(HOST_ROOT)
        return f"{PUBLIC_HOST_PREFIX}/{rel.as_posix()}"
    except ValueError:
        return str(path)


def decode_data_url(url: str) -> tuple[str, bytes] | None:
    match = re.match(r"^data:(image/[^;,]+)(?:;[^,]*)?;base64,(.*)$", url, re.DOTALL)
    if not match:
        return None
    mime = match.group(1).lower()
    raw = base64.b64decode(match.group(2), validate=False)
    return mime, raw


def save_image(raw: bytes, mime: str, session_dir: Path, index: int) -> Path:
    session_dir.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(raw).hexdigest()[:12]
    path = session_dir / f"image-{index:02d}-{digest}{extension_for_mime(mime)}"
    path.write_bytes(raw)
    return path


def ocr_image(path: Path) -> tuple[str, tuple[int, int] | None, str | None]:
    if Image is None or pytesseract is None:
        return "", None, "OCR 依赖未安装；容器镜像会安装 pillow/pytesseract。"
    try:
        with Image.open(path) as image:
            size = image.size
            # Screenshots usually OCR better in RGB.
            if image.mode not in ("RGB", "L"):
                image = image.convert("RGB")
            try:
                text = pytesseract.image_to_string(image, lang=OCR_LANG)
            except pytesseract.TesseractError:
                text = pytesseract.image_to_string(image, lang="eng")
            return text.strip(), size, None
    except Exception as exc:  # noqa: BLE001 - report OCR errors inside prompt text.
        return "", None, f"{type(exc).__name__}: {exc}"


def image_note(path: Path, mime: str, ocr_text: str, size: tuple[int, int] | None, error: str | None) -> str:
    details = [
        f"图片已由 OpenDeepSeek image bridge 本地解析并保存。",
        f"路径：{public_path(path)}",
        f"类型：{mime}",
    ]
    if size:
        details.append(f"尺寸：{size[0]}x{size[1]}")
    if ocr_text:
        clipped = ocr_text.strip()
        if len(clipped) > 4000:
            clipped = clipped[:4000] + "\n...[OCR 文本过长，已截断]"
        details.append("OCR 文本：\n" + clipped)
    else:
        details.append("OCR 文本：未识别到清晰文字。请在生成网页/PPT时仍把该图片作为证据图片素材使用。")
    if error:
        details.append(f"OCR 备注：{error}")
    details.append("如果用户要求生成网页或 PPT，请把这张图片复制到输出目录的 assets/ 下，并在页面里按证据图使用。")
    return "\n".join(details)


def content_part_to_text(part: Any, session_dir: Path, image_counter: list[int]) -> str:
    if isinstance(part, str):
        return part
    if not isinstance(part, dict):
        return str(part)

    part_type = part.get("type")
    if part_type == "text":
        return str(part.get("text", ""))

    image_url = part.get("image_url")
    if part_type == "image_url" or image_url:
        url = ""
        if isinstance(image_url, dict):
            url = str(image_url.get("url", ""))
        elif image_url:
            url = str(image_url)

        decoded = decode_data_url(url)
        if not decoded:
            return (
                "[图片附件]\n"
                f"OpenDeepSeek image bridge 收到非 data URL 图片：{url[:200]}\n"
                "当前无法本地读取该 URL，请用户重新上传图片或粘贴图片文字。"
            )

        mime, raw = decoded
        image_counter[0] += 1
        path = save_image(raw, mime, session_dir, image_counter[0])
        ocr_text, size, error = ocr_image(path)
        return f"[图片 {image_counter[0]}]\n{image_note(path, mime, ocr_text, size, error)}"

    return json.dumps(part, ensure_ascii=False)


def sanitize_messages(messages: list[Any]) -> tuple[list[Any], int]:
    session_dir = UPLOAD_ROOT / f"{now_slug()}-{uuid.uuid4().hex[:8]}"
    image_counter = [0]
    sanitized: list[Any] = []

    for message in messages:
        if not isinstance(message, dict):
            sanitized.append(message)
            continue

        new_message = dict(message)
        content = message.get("content")
        if isinstance(content, list):
            parts = [content_part_to_text(part, session_dir, image_counter) for part in content]
            new_message["content"] = "\n\n".join(part for part in parts if part).strip()
        sanitized.append(new_message)

    if image_counter[0]:
        note = (
            "OpenDeepSeek image bridge 已把本轮/历史图片转换为本地文件路径和 OCR 文本。"
            "下游 DeepSeek V4 Flash 只能看到这些文字和路径，不会收到 image_url。"
        )
        if sanitized and isinstance(sanitized[-1], dict):
            last_content = str(sanitized[-1].get("content", ""))
            sanitized[-1]["content"] = f"{last_content}\n\n[系统桥接说明]\n{note}".strip()

    return sanitized, image_counter[0]


def sanitize_payload(payload: Any) -> tuple[Any, int]:
    if not isinstance(payload, dict):
        return payload, 0
    if isinstance(payload.get("messages"), list):
        payload = dict(payload)
        payload["messages"], count = sanitize_messages(payload["messages"])
        return payload, count
    return payload, 0


def text_from_content(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict):
                if item.get("type") == "text":
                    parts.append(str(item.get("text", "")))
                elif item.get("type") == "image_url" or item.get("image_url"):
                    parts.append("[image]")
            else:
                parts.append(str(item))
        return "\n".join(parts)
    if content is None:
        return ""
    return str(content)


def recent_user_text(messages: list[Any], limit: int = 4) -> str:
    chunks: list[str] = []
    for message in reversed(messages):
        if not isinstance(message, dict):
            continue
        if message.get("role") != "user":
            continue
        chunks.append(text_from_content(message.get("content")))
        if len(chunks) >= limit:
            break
    return "\n".join(reversed(chunks))


def should_route_to_hermes(payload: dict[str, Any], image_count: int) -> tuple[bool, str]:
    """Route simple chat to DeepSeek directly, true automation to Hermes Agent."""
    if not ENABLE_LIGHTWEIGHT_ROUTING:
        return True, "routing-disabled"
    if not DEEPSEEK_API_KEY:
        return True, "missing-deepseek-key"
    if image_count:
        return True, "image:attachment"
    messages = payload.get("messages")
    if not isinstance(messages, list):
        return True, "no-messages"

    text = recent_user_text(messages).strip()
    lowered = text.lower()
    if lowered.startswith(("/agent", "agent:", "hermes:")):
        return True, "forced-agent"
    if lowered.startswith(("/fast", "fast:", "chat:")):
        return False, "forced-fast"

    route = classify_text_route(text)
    if payload.get("tools") or payload.get("tool_choice"):
        if DELEGATE_OPENWEBUI_NATIVE_TOOLS:
            label = route.split(":", 1)[0] if route else ""
            if label not in {"host-path", "artifact", "schedule", "memory", "image"}:
                return False, "openwebui-native-tools"
        if not route:
            return True, "explicit-tools"
    if route:
        return True, route
    return False, "simple-chat"


def classify_text_route(text: str) -> str | None:
    for index, rule in enumerate(ROUTE_RULES):
        for pattern in rule["patterns"]:
            if re.search(pattern, text, re.IGNORECASE):
                return f"{rule['label']}:{index}:{pattern}"
    return None


def route_prompt_for_testing(
    text: str,
    image_count: int = 0,
    has_tools: bool = False,
    lightweight: bool = True,
    has_deepseek_key: bool = True,
) -> dict[str, str]:
    payload: dict[str, Any] = {"messages": [{"role": "user", "content": text}]}
    if has_tools:
        payload["tools"] = [{"type": "function", "function": {"name": "dummy", "parameters": {}}}]

    original_lightweight = ENABLE_LIGHTWEIGHT_ROUTING
    original_deepseek_key = DEEPSEEK_API_KEY
    globals()["ENABLE_LIGHTWEIGHT_ROUTING"] = lightweight
    globals()["DEEPSEEK_API_KEY"] = "test-key" if has_deepseek_key else ""
    try:
        route_hermes, reason = should_route_to_hermes(payload, image_count)
    finally:
        globals()["ENABLE_LIGHTWEIGHT_ROUTING"] = original_lightweight
        globals()["DEEPSEEK_API_KEY"] = original_deepseek_key
    return {"route": "hermes" if route_hermes else "deepseek-lite", "reason": reason}


def is_artifact_task(text: str) -> bool:
    return any(re.search(pattern, text, re.IGNORECASE) for pattern in ARTIFACT_PATTERNS)


def is_realtime_research_task(text: str) -> bool:
    return any(re.search(pattern, text, re.IGNORECASE) for pattern in REALTIME_RESEARCH_PATTERNS)


def should_skip_realtime_search(text: str) -> bool:
    return bool(re.search(r"测试路由|不用展开新闻|ROUTED_OK|只测试|无需搜索", text, re.IGNORECASE))


def realtime_search_snapshot(query: str) -> str:
    """Fetch a small SearXNG snapshot before Hermes sees the task.

    Hermes' bundled web_search tool is only present when a web backend such as
    Firecrawl/Exa/Tavily is configured. OpenDeepSeek ships SearXNG instead, so
    the bridge injects a compact search snapshot for realtime/news tasks and
    prevents the model from burning iterations on an unavailable web_search tool.
    """
    if not REALTIME_SEARCH_ENABLED:
        return "OpenDeepSeek 搜索快照：未启用 OPDS_REALTIME_SEARCH_ENABLED。"
    if should_skip_realtime_search(query):
        return "OpenDeepSeek 搜索快照：本轮是路由/性能测试，已跳过联网搜索。"

    encoded = quote_plus(query[:300])
    if "{query}" in REALTIME_SEARCH_URL:
        url = REALTIME_SEARCH_URL.replace("{query}", encoded)
    elif "<query>" in REALTIME_SEARCH_URL:
        url = REALTIME_SEARCH_URL.replace("<query>", encoded)
    else:
        joiner = "&" if "?" in REALTIME_SEARCH_URL else "?"
        url = f"{REALTIME_SEARCH_URL}{joiner}q={encoded}&format=json"

    try:
        response = requests.get(url, timeout=REALTIME_SEARCH_TIMEOUT)
        response.raise_for_status()
        data = response.json()
    except Exception as exc:  # noqa: BLE001 - keep agent from retry loops.
        return (
            "OpenDeepSeek 搜索快照：本地搜索服务暂不可用。"
            f"错误：{type(exc).__name__}: {exc}。"
            "不要调用 web_search；如果必须要今日新闻，请提示用户用 `docker compose --profile full up -d` 启动 SearXNG。"
        )

    results = data.get("results") if isinstance(data, dict) else None
    if not isinstance(results, list) or not results:
        return "OpenDeepSeek 搜索快照：本地搜索服务返回空结果；不要编造今日新闻。"

    lines = ["OpenDeepSeek 已先用本地 SearXNG 做了搜索快照，请优先基于这些结果整理，不要再调用 web_search："]
    for index, item in enumerate(results[:REALTIME_SEARCH_MAX_RESULTS], 1):
        if not isinstance(item, dict):
            continue
        title = str(item.get("title") or "无标题").strip()
        url_value = str(item.get("url") or "").strip()
        snippet = str(item.get("content") or item.get("snippet") or "").strip()
        if len(snippet) > 500:
            snippet = snippet[:500].rstrip() + "..."
        lines.append(f"{index}. {title}\n   URL: {url_value}\n   摘要: {snippet}")
    return "\n".join(lines)


def read_shared_memory_snapshot() -> str:
    try:
        if not SHARED_MEMORY_PATH.exists():
            return ""
        text = SHARED_MEMORY_PATH.read_text(encoding="utf-8", errors="replace").strip()
    except Exception as exc:  # noqa: BLE001 - memory sync should never break chat.
        log(f"shared memory unavailable: {exc}")
        return ""
    if len(text) > MEMORY_SNAPSHOT_MAX_CHARS:
        text = text[-MEMORY_SNAPSHOT_MAX_CHARS:]
    return text


def lite_system_message() -> dict[str, str]:
    parts = [
        "你是 OpenDeepSeek 的轻量问答路径：Open WebUI → Smart Bridge → DeepSeek V4 Flash。",
        "普通解释、翻译、闲聊、写作可以直接回答，默认中文、简洁、不要啰嗦。",
        "不要声称已经操作电脑、创建文件、设置提醒、读取桌面、写入记忆或调用工具。",
        "如果用户需要本机文件、/host、桌面、生成网页/PPT/文件、定时提醒、长期记忆、图片/OCR、终端、工具或自动化，请提醒：这类请求应走 Hermes Agent；可以直接说出执行任务，或在消息开头加 /agent 强制进入 Hermes。",
    ]
    snapshot = read_shared_memory_snapshot()
    if snapshot:
        parts.append("[OpenDeepSeek 共享记忆摘要]\n" + snapshot)
    return {"role": "system", "content": "\n".join(parts)}


def prepare_deepseek_payload(payload: dict[str, Any], preserve_tools: bool = False) -> bytes:
    direct = dict(payload)
    direct["model"] = DEFAULT_MODEL
    direct.setdefault("thinking", {"type": "disabled"})
    messages = direct.get("messages")
    if isinstance(messages, list):
        direct["messages"] = [lite_system_message(), *messages]
    # Plain chat should not leak OpenWebUI/Hermes-only params. If OpenWebUI
    # injected native tools, preserve them so OpenWebUI can complete that loop.
    if not preserve_tools:
        direct.pop("tools", None)
        direct.pop("tool_choice", None)
    return json.dumps(direct, ensure_ascii=False).encode("utf-8")


def host_path_to_local(path: str) -> str:
    if not path.startswith("/host"):
        return path
    if not HOST_DISPLAY_PREFIX or HOST_DISPLAY_PREFIX == "/host":
        return path
    suffix = path.removeprefix("/host").lstrip("/")
    if not suffix:
        return HOST_DISPLAY_PREFIX
    return f"{HOST_DISPLAY_PREFIX}/{suffix}"


def file_url_for(path: str) -> str | None:
    if not path.startswith("/"):
        return None
    try:
        return Path(path).as_uri()
    except ValueError:
        return None


def host_paths_in_text(text: str) -> list[str]:
    paths: list[str] = []
    for match in re.finditer(r"(?<![\w])(/host(?:/[^\s`'\"<>，。；;、]*)?)", text):
        path = match.group(1).rstrip(".,)")
        if path and path not in paths:
            paths.append(path)
    return paths


def append_path_notes(text: str) -> str:
    if "本机可找路径" in text or "file://" in text:
        return text
    paths = host_paths_in_text(text)
    if not paths:
        return text

    lines = ["", "", "本机可找路径："]
    for path in paths[:8]:
        local_path = host_path_to_local(path)
        if local_path != path:
            lines.append(f"- `{path}` → `{local_path}`")
        else:
            lines.append(f"- `{path}`")
        url = file_url_for(local_path)
        if url:
            lines.append(f"  打开：`{url}`")
    return text.rstrip() + "\n".join(lines)


def augment_openai_response(content: bytes, upstream_name: str) -> bytes:
    if upstream_name != "hermes":
        return content
    try:
        payload = json.loads(content.decode("utf-8"))
    except Exception:
        return content
    changed = False
    choices = payload.get("choices")
    if isinstance(choices, list):
        for choice in choices:
            if not isinstance(choice, dict):
                continue
            message = choice.get("message")
            if not isinstance(message, dict):
                continue
            text = message.get("content")
            if isinstance(text, str):
                updated = append_path_notes(text)
                if updated != text:
                    message["content"] = updated
                    changed = True
    if not changed:
        return content
    return json.dumps(payload, ensure_ascii=False).encode("utf-8")


def extract_openai_message_content(content: bytes, upstream_name: str) -> str:
    try:
        payload = json.loads(augment_openai_response(content, upstream_name).decode("utf-8"))
    except Exception:
        return content.decode("utf-8", errors="replace")
    choices = payload.get("choices")
    if isinstance(choices, list) and choices:
        choice = choices[0]
        if isinstance(choice, dict):
            message = choice.get("message")
            if isinstance(message, dict):
                text = message.get("content") or message.get("reasoning_content")
                if isinstance(text, str):
                    return text
    error = payload.get("error")
    if error:
        return json.dumps(error, ensure_ascii=False)
    return json.dumps(payload, ensure_ascii=False)


def human_route_reason(reason: str) -> str:
    label = reason.split(":", 1)[0]
    if label == "image":
        return "图片/OCR 任务"
    if reason in {"explicit-tools", "forced-agent"}:
        return "用户明确要求工具/Agent 能力"
    if reason == "openwebui-native-tools":
        return "OpenWebUI 原生工具任务"
    if reason in {"missing-deepseek-key", "routing-disabled", "no-messages", "non-chat"}:
        return "需要 Agent 执行路径"
    for rule in ROUTE_RULES:
        if rule["label"] == label:
            return str(rule["summary"])
    return "普通聊天做不到的 Agent 任务"


def friendly_upstream_error(upstream_name: str, error: str, status_code: int | None = None) -> str:
    layer = "Hermes Agent" if upstream_name == "hermes" else "DeepSeek 轻量问答"
    status = f"HTTP {status_code}" if status_code else "连接错误"
    hints = [
        "确认 Docker 服务还在运行：`docker compose ps`。",
        "查看最近日志：`docker compose logs hermes hermes-bridge --tail 120`。",
    ]
    if upstream_name == "hermes":
        hints.append("如果是网页/PPT/长文件任务，不要降低 `HERMES_AGENT_MAX_TOKENS=32768`。")
    else:
        hints.append("如果是 API Key、余额或网络问题，请检查 DeepSeek 控制台和 `.env`。")
    return (
        f"任务没有完成，卡在 {layer} 层（{status}）。\n\n"
        f"错误摘要：{error[:1200]}\n\n"
        "可以这样排查：\n- " + "\n- ".join(hints)
    )


def route_reason_header(reason: str) -> str:
    parts = reason.split(":", 2)
    if len(parts) >= 2 and parts[1].isdigit():
        return f"{parts[0]}:{parts[1]}"
    return re.sub(r"[^A-Za-z0-9_.:-]", "_", reason)[:160]


def hermes_system_message(payload: dict[str, Any], reason: str) -> dict[str, str]:
    text = recent_user_text(payload.get("messages", []) if isinstance(payload.get("messages"), list) else [])
    parts = [
        "OpenDeepSeek Smart Bridge 已把本轮请求路由到 Hermes Agent。",
        "这是执行路径，不是普通聊天。涉及 /host、文件、网页、PPT、提醒、记忆、图片或终端时，必须实际使用工具完成。",
        "在回复“已保存/已生成”前，必须用工具验证目标文件存在且大小大于 0；验证失败就明确说失败原因。",
    ]
    if HOST_DISPLAY_PREFIX and HOST_DISPLAY_PREFIX != "/host":
        parts.append(f"用户看到的本机路径前缀是 {HOST_DISPLAY_PREFIX}；容器内 /host/... 对应本机 {HOST_DISPLAY_PREFIX}/...。")
        parts.append("回复文件路径时同时给出 /host 路径和本机路径。")
    if is_artifact_task(text):
        parts.append(
            "网页/PPT/HTML 等大文件不要一次性塞进超长工具参数；如内容较长，请分段写入或用脚本生成，"
            "避免 tool call 被截断。最后用 ls/wc/test 验证文件。"
        )
    if is_realtime_research_task(text):
        parts.append(
            "早报、今日资讯、最新动态、调研和搜索类请求不能由普通聊天凭记忆回答；"
            "不要调用不可见或不可用的 web_search 工具，不要在工具不可用时反复自我纠错。"
            "如果下面有 OpenDeepSeek 搜索快照，请直接基于快照整理；如果快照不可用，必须明确说明需要开启本地搜索，不要编造今日新闻。"
        )
        parts.append(realtime_search_snapshot(text))
    parts.append(f"路由原因：{reason}")
    return {"role": "system", "content": "\n".join(parts)}


def prepare_hermes_payload(payload: dict[str, Any], reason: str) -> tuple[bytes, bool]:
    agent = dict(payload)
    requested_tokens = agent.get("max_tokens")
    if not isinstance(requested_tokens, int) or requested_tokens < HERMES_AGENT_MAX_TOKENS:
        agent["max_tokens"] = HERMES_AGENT_MAX_TOKENS
    agent["stream"] = bool(agent.get("stream")) and HERMES_AGENT_STREAM
    messages = agent.get("messages")
    if isinstance(messages, list):
        agent["messages"] = [hermes_system_message(agent, reason), *messages]
    return json.dumps(agent, ensure_ascii=False).encode("utf-8"), bool(agent.get("stream"))


def hop_by_hop_headers() -> set[str]:
    return {
        "connection",
        "content-encoding",
        "keep-alive",
        "proxy-authenticate",
        "proxy-authorization",
        "te",
        "trailers",
        "transfer-encoding",
        "upgrade",
        "host",
        "content-length",
    }


class BridgeHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:  # noqa: N802
        self.proxy()

    def do_POST(self) -> None:  # noqa: N802
        self.proxy()

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "authorization,content-type")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, fmt: str, *args: Any) -> None:
        log(fmt % args)

    def write_chunk(self, chunk: bytes) -> bool:
        try:
            self.wfile.write(f"{len(chunk):X}\r\n".encode("ascii"))
            self.wfile.write(chunk)
            self.wfile.write(b"\r\n")
            self.wfile.flush()
            return True
        except BrokenPipeError:
            return False

    def write_sse_event(self, payload: dict[str, Any] | str) -> bool:
        if isinstance(payload, str):
            data = f"data: {payload}\n\n".encode("utf-8")
        else:
            data = f"data: {json.dumps(payload, ensure_ascii=False)}\n\n".encode("utf-8")
        return self.write_chunk(data)

    def sse_chunk(self, stream_id: str, model: str, content: str = "", role: str | None = None, finish_reason: str | None = None) -> dict[str, Any]:
        delta: dict[str, str] = {}
        if role:
            delta["role"] = role
        if content:
            delta["content"] = content
        return {
            "id": stream_id,
            "object": "chat.completion.chunk",
            "created": int(dt.datetime.now(dt.UTC).timestamp()),
            "model": model,
            "choices": [{"index": 0, "delta": delta, "finish_reason": finish_reason}],
        }

    def proxy_hermes_with_progress(
        self,
        target_url: str,
        headers: dict[str, str],
        body_bytes: bytes,
        model: str,
        reason: str,
        request_id: str,
    ) -> None:
        started = time.perf_counter()
        stream_id = f"chatcmpl-opds-{uuid.uuid4().hex}"
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("X-Accel-Buffering", "no")
        self.send_header("X-OpenDeepSeek-Request-Id", request_id)
        self.send_header("X-OpenDeepSeek-Route", "hermes")
        self.send_header("X-OpenDeepSeek-Route-Reason", route_reason_header(reason))
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()

        progress_text = HERMES_PROGRESS_MESSAGE
        progress_text = progress_text.rstrip() + f"\n识别为：{human_route_reason(reason)}\n\n"
        if not self.write_sse_event(self.sse_chunk(stream_id, model, progress_text, role="assistant")):
            log("client disconnected before Hermes progress stream started")
            return

        try:
            response = requests.request(
                self.command,
                target_url,
                headers=headers,
                data=body_bytes if body_bytes else None,
                stream=False,
                timeout=REQUEST_TIMEOUT,
            )
            if response.status_code >= 400:
                final_text = friendly_upstream_error("hermes", response.text, response.status_code)
                log_event(
                    "upstream_error",
                    request_id=request_id,
                    upstream="hermes",
                    status=response.status_code,
                    reason=reason,
                    duration_ms=round((time.perf_counter() - started) * 1000, 1),
                )
            else:
                final_text = extract_openai_message_content(response.content, "hermes")
        except Exception as exc:  # noqa: BLE001
            final_text = friendly_upstream_error("hermes", str(exc))
            log_event(
                "upstream_exception",
                request_id=request_id,
                upstream="hermes",
                reason=reason,
                error_type=type(exc).__name__,
                duration_ms=round((time.perf_counter() - started) * 1000, 1),
            )

        if final_text:
            if not self.write_sse_event(self.sse_chunk(stream_id, model, final_text)):
                log("client disconnected while writing Hermes final stream")
                return
        self.write_sse_event(self.sse_chunk(stream_id, model, finish_reason="stop"))
        self.write_sse_event("[DONE]")
        try:
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
        except BrokenPipeError:
            log("client disconnected at end of Hermes progress stream")
        log_event(
            "request_complete",
            request_id=request_id,
            upstream="hermes",
            route_reason=reason,
            progress_stream=True,
            duration_ms=round((time.perf_counter() - started) * 1000, 1),
        )

    def proxy(self) -> None:
        started = time.perf_counter()
        request_id = uuid.uuid4().hex[:12]
        if self.path == "/health":
            body = b"ok"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        target_base_url = HERMES_BASE_URL
        target_url = urljoin(target_base_url + "/", self.path.lstrip("/").removeprefix("v1/"))
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in hop_by_hop_headers()
        }
        # Open WebUI/aiohttp may advertise zstd/br. The bridge rewrites
        # response body framing itself, so ask upstreams for plain JSON/SSE and
        # avoid handing compressed bytes to Open WebUI as if they were UTF-8.
        headers["Accept-Encoding"] = "identity"
        headers.pop("Authorization", None)
        if HERMES_API_KEY:
            # Do not pass Open WebUI's placeholder key through to Hermes.
            headers["Authorization"] = f"Bearer {HERMES_API_KEY}"

        body_bytes = b""
        stream_response = False
        progress_stream = False
        route_reason = "non-chat"
        requested_model = "hermes-agent"
        upstream_name = "hermes"
        preserve_native_tools = False
        if self.command in {"POST", "PUT", "PATCH"}:
            length = int(self.headers.get("Content-Length", "0") or "0")
            body_bytes = self.rfile.read(length) if length else b""
            if body_bytes and "application/json" in self.headers.get("Content-Type", ""):
                try:
                    payload = json.loads(body_bytes.decode("utf-8"))
                    payload, image_count = sanitize_payload(payload)
                    client_requested_stream = bool(payload.get("stream"))
                    stream_response = client_requested_stream
                    requested_model = str(payload.get("model") or "hermes-agent")
                    if image_count:
                        log(f"sanitized {image_count} image(s) for {self.path}")
                    route_hermes = True
                    reason = "non-chat"
                    if self.path.rstrip("/") == "/v1/chat/completions" and isinstance(payload, dict):
                        route_hermes, reason = should_route_to_hermes(payload, image_count)
                    route_reason = reason
                    if route_hermes:
                        body_bytes, stream_response = prepare_hermes_payload(payload, reason)
                        progress_stream = (
                            self.path.rstrip("/") == "/v1/chat/completions"
                            and client_requested_stream
                            and HERMES_PROGRESS_STREAM
                            and not stream_response
                        )
                        upstream_name = "hermes"
                    else:
                        target_base_url = DEEPSEEK_BASE_URL
                        target_url = urljoin(target_base_url + "/", self.path.lstrip("/").removeprefix("v1/"))
                        if DEEPSEEK_API_KEY:
                            headers["Authorization"] = f"Bearer {DEEPSEEK_API_KEY}"
                        preserve_native_tools = reason == "openwebui-native-tools"
                        body_bytes = prepare_deepseek_payload(payload, preserve_tools=preserve_native_tools)
                        stream_response = client_requested_stream
                        upstream_name = "deepseek-lite"
                    log(f"route {self.path} -> {upstream_name} ({reason}) stream={stream_response} progress={progress_stream}")
                    log_event(
                        "route_decision",
                        request_id=request_id,
                        path=self.path,
                        upstream=upstream_name,
                        route="hermes" if route_hermes else "deepseek-lite",
                        reason=reason,
                        stream=stream_response,
                        progress_stream=progress_stream,
                        preserve_native_tools=preserve_native_tools,
                    )
                    headers["Content-Type"] = "application/json"
                except Exception as exc:  # noqa: BLE001
                    log(f"payload sanitize failed, forwarding original body: {exc}")
                    log_event("payload_sanitize_failed", request_id=request_id, error_type=type(exc).__name__)

        if progress_stream:
            self.proxy_hermes_with_progress(target_url, headers, body_bytes, requested_model, route_reason, request_id)
            return

        try:
            response = requests.request(
                self.command,
                target_url,
                headers=headers,
                data=body_bytes if body_bytes else None,
                stream=stream_response,
                timeout=REQUEST_TIMEOUT,
            )
        except Exception as exc:  # noqa: BLE001
            log_event(
                "upstream_exception",
                request_id=request_id,
                upstream=upstream_name,
                route_reason=route_reason,
                error_type=type(exc).__name__,
                duration_ms=round((time.perf_counter() - started) * 1000, 1),
            )
            body = json.dumps({"error": friendly_upstream_error(upstream_name, str(exc))}, ensure_ascii=False).encode("utf-8")
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("X-OpenDeepSeek-Request-Id", request_id)
            self.send_header("X-OpenDeepSeek-Route", upstream_name)
            self.send_header("X-OpenDeepSeek-Route-Reason", route_reason_header(route_reason))
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if not stream_response:
            if response.status_code >= 400:
                raw_error = response.text[:1200]
                content = json.dumps(
                    {"error": friendly_upstream_error(upstream_name, raw_error, response.status_code)},
                    ensure_ascii=False,
                ).encode("utf-8")
                log_event(
                    "upstream_error",
                    request_id=request_id,
                    upstream=upstream_name,
                    route_reason=route_reason,
                    status=response.status_code,
                    duration_ms=round((time.perf_counter() - started) * 1000, 1),
                )
            else:
                content = augment_openai_response(response.content, upstream_name)
            self.send_response(response.status_code)
            for key, value in response.headers.items():
                if key.lower() in hop_by_hop_headers():
                    continue
                self.send_header(key, value)
            self.send_header("X-OpenDeepSeek-Request-Id", request_id)
            self.send_header("X-OpenDeepSeek-Route", upstream_name)
            self.send_header("X-OpenDeepSeek-Route-Reason", route_reason_header(route_reason))
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
            self.wfile.flush()
            log_event(
                "request_complete",
                request_id=request_id,
                upstream=upstream_name,
                route_reason=route_reason,
                status=response.status_code,
                stream=False,
                duration_ms=round((time.perf_counter() - started) * 1000, 1),
            )
            return

        self.send_response(response.status_code)
        for key, value in response.headers.items():
            if key.lower() in hop_by_hop_headers():
                continue
            self.send_header(key, value)
        self.send_header("X-OpenDeepSeek-Request-Id", request_id)
        self.send_header("X-OpenDeepSeek-Route", upstream_name)
        self.send_header("X-OpenDeepSeek-Route-Reason", route_reason_header(route_reason))
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()

        for chunk in response.iter_content(chunk_size=8192):
            if not chunk:
                continue
            try:
                self.wfile.write(f"{len(chunk):X}\r\n".encode("ascii"))
                self.wfile.write(chunk)
                self.wfile.write(b"\r\n")
                self.wfile.flush()
            except BrokenPipeError:
                log(f"client disconnected while streaming {upstream_name}")
                return
        try:
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
        except BrokenPipeError:
            log(f"client disconnected at end of {upstream_name} stream")
        log_event(
            "request_complete",
            request_id=request_id,
            upstream=upstream_name,
            route_reason=route_reason,
            status=response.status_code,
            stream=True,
            duration_ms=round((time.perf_counter() - started) * 1000, 1),
        )


def main() -> None:
    UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)
    routing = "on" if ENABLE_LIGHTWEIGHT_ROUTING and DEEPSEEK_API_KEY else "off"
    log(
        f"listening on {LISTEN_HOST}:{LISTEN_PORT}; hermes={HERMES_BASE_URL}; "
        f"deepseek={DEEPSEEK_BASE_URL}; lite-routing={routing}; upload_root={UPLOAD_ROOT}"
    )
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), BridgeHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
