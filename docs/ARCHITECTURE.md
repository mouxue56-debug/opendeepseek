# OpenDeepSeek 架构深度文档

> 面向开发者、贡献者和想要 fork 本项目的人。  
> 版本：v0.4.2 | 最后更新：2026-05-04

---

## 1. 设计哲学

OpenDeepSeek 的默认架构不是“Open WebUI + 任意 LLM”，而是三件套，中间多一层很薄的智能桥接适配：

```
普通问答：Open WebUI → Smart Bridge → DeepSeek V4
真任务：  Open WebUI → Smart Bridge → Hermes Agent → DeepSeek V4
```

三层各司其职：

- **Open WebUI**：用户体验层，提供网页、PWA、桌面 App、知识库、上传、多用户管理。
- **Smart Bridge**：适配层，处理 Open WebUI 上传的 `image_url` 图片；同时做轻量路由，普通问答直连 DeepSeek，真任务进入 Hermes Agent。
- **Hermes Agent**：Agent 内核层，提供 Memory、Skills、Cron、Subagent、IM 桥接和工具调度。
- **DeepSeek V4**：模型层，提供 `deepseek-v4-flash` / `deepseek-v4-pro` 推理能力。

项目初心是让用户在 Open WebUI 里说“30 分钟后提醒我喝水”，请求真的进入 Hermes Cron skill，而不是只让模型口头答应。Hermes 必须保留在默认架构中；但“你好/翻译/解释一下”这类普通问答不需要背着完整工具上下文跑，所以由 Smart Bridge 直连 DeepSeek，降低延迟和 token 消耗。

---

## 2. 架构总览

```
┌──────────────────────────────────────────────────────────┐
│                      终端层                               │
│   浏览器 / 手机 PWA / 桌面 App                            │
└───────────────────────────┬──────────────────────────────┘
                            │ HTTP :3000
┌───────────────────────────▼──────────────────────────────┐
│              Open WebUI v0.9.2（体验层）                  │
│   • 对话历史 / 知识库 RAG / 上传 / 多模态                  │
│   • 中文界面 / PWA / 桌面 App                              │
│   • 把 hermes-agent 当 OpenAI-compatible model backend     │
│   • OPENAI_API_BASE_URL=http://hermes-bridge:8765/v1       │
└───────────────────────────┬──────────────────────────────┘
                            │ Docker 内网 :8765
┌───────────────────────────▼──────────────────────────────┐
│              Hermes Smart Bridge（适配 + 路由层）         │
│   • 保存图片到 /host/OpenDeepSeek-Inputs                  │
│   • OCR 中文/英文截图文字                                  │
│   • 把 image_url 改写成纯文本路径 + OCR 摘要               │
│   • 普通问答 → DeepSeek V4 Flash（thinking 默认关闭）      │
│   • 文件/提醒/记忆/图片/工具 → Hermes Agent                │
└──────────────┬────────────────────────────┬──────────────┘
               │ 普通问答 HTTPS             │ 真任务 Docker 内网 :8642
┌──────────────▼──────────────────┐ ┌───────▼──────────────────────────┐
│ DeepSeek V4 Flash（轻量路径）    │ │ Hermes Agent v2026.4.23（内核层） │
│ • 低延迟 / 低 token              │ │ • Memory / Skills / Cron          │
│ • SSE stream 原样透传            │ │ • Subagent / IM Bridge            │
└─────────────────────────────────┘ │ • provider: deepseek              │
                                    │ • 对外暴露 hermes-agent model      │
                                    └───────┬──────────────────────────┘
                                            │ HTTPS api.deepseek.com
┌───────────────────────────────────────────▼──────────────┐
│                    DeepSeek V4（Agent 路径模型层）        │
│   • deepseek-v4-flash：默认，快速便宜                      │
│   • deepseek-v4-pro：复杂推理                              │
└──────────────────────────────────────────────────────────┘

可选：

┌──────────────────┐
│ SearXNG          │
│ --profile full   │
│ :8889 → :8080    │
└──────────────────┘
```

默认启动命令：

```bash
docker compose up -d
```

启用自托管搜索：

```bash
docker compose --profile full up -d
```

---

## 3. 一次请求的生命周期

### 3.1 普通问答轻量路径

以用户输入“用一句话解释 OpenDeepSeek 是什么”为例：

| 步骤 | 发生了什么 | 关键点 |
|---|---|---|
| 1 | 浏览器向 Open WebUI `:3000` 发送消息 | 用户仍使用同一个界面 |
| 2 | Open WebUI 调用 `http://hermes-bridge:8765/v1/chat/completions` | 模型仍显示为 `hermes-agent` |
| 3 | Smart Bridge 判断没有图片、文件、提醒、记忆、工具意图 | 路由原因为 `simple-chat` |
| 4 | Smart Bridge 直接调用 DeepSeek V4 Flash | `thinking` 默认关闭，避免 Flash 被误当思考模型 |
| 5 | 如果 Open WebUI 请求 `stream=true`，Smart Bridge 按 SSE 流式透传 | 体验接近原生 Open WebUI |

本地验证结果：

```text
普通问答：0.91s，prompt_tokens=16
流式首包：0.69s
```

### 3.2 真任务 Agent 路径

以用户在 Open WebUI 输入“明天早上 8 点提醒我提交周报”为例：

| 步骤 | 发生了什么 | 关键点 |
|---|---|---|
| 1 | 浏览器向 Open WebUI `:3000` 发送消息 | 用户只面对 Web/PWA/桌面体验层 |
| 2 | Open WebUI 调用 `http://hermes-bridge:8765/v1/chat/completions` | 模型 id 是 `hermes-agent` |
| 3 | Smart Bridge 检测到提醒/文件/记忆/图片/工具关键词 | 路由进入 Hermes |
| 4 | 如有图片，Smart Bridge 本地落盘 + OCR | `image_url` 会变成 `/host/OpenDeepSeek-Inputs/...` 路径 + OCR 摘要 |
| 5 | Hermes 解析请求、加载 SOUL.md、判断是否需要工具 | Cron/Memory/Skill 在这里生效 |
| 6 | Hermes 用原生 `deepseek` provider 调 DeepSeek V4 | 使用 `.env` 中的 `DEEPSEEK_API_KEY` |
| 7 | Smart Bridge 为 Hermes 任务提高输出预算，并默认关闭 Agent 流式回传 | 避免长网页/PPT任务出现半截 tool call 或空回复 |
| 8 | 如需提醒，Hermes 创建 Cron 任务并持久化 | 不是模型口头承诺 |
| 9 | Hermes 返回结果，Open WebUI 渲染并保存对话 | 用户仍在熟悉的聊天界面里 |
| 10 | 若回复包含 `/host/...`，Smart Bridge 追加本机可找路径和 `file://` 地址 | 小白不需要理解 Docker 路径映射 |

这两条路径都是 smoke test 必须验证的核心路径。只检查网页能打开不够，必须确认轻量问答能直连、真任务能进 Hermes 并实际产生工具结果。

---

## 4. 容器拓扑

### hermes

```yaml
image: nousresearch/hermes-agent:v2026.4.23
command: gateway run
ports:
  - "${BIND_HOST:-127.0.0.1}:8642:8642"
environment:
  - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
  - HERMES_INFERENCE_PROVIDER=deepseek
  - DEFAULT_MODEL=${DEFAULT_MODEL:-deepseek-v4-flash}
  - API_SERVER_ENABLED=true
  - API_SERVER_KEY=${HERMES_API_KEY}
  - API_SERVER_PORT=8642
```

Hermes 镜像首次启动会生成 `/opt/data/config.yaml`，默认 model 可能是 `anthropic/claude-opus-4.6`。因此 `setup.sh` 和 onboarding server 在 Hermes healthy 后会运行：

```bash
./scripts/hermes-fix-model.sh deepseek-v4-flash
```

这个修复会把 Hermes 内部默认 model 改成 DeepSeek V4，并重启 hermes 容器。

### open-webui

```yaml
image: ghcr.io/open-webui/open-webui:0.9.2
ports:
  - "${BIND_HOST:-127.0.0.1}:3000:8080"
environment:
  - OPENAI_API_BASE_URL=http://hermes-bridge:8765/v1
  - OPENAI_API_KEY=${HERMES_API_KEY}
  - WEBUI_NAME=OpenDeepSeek
  - DEFAULT_MODELS=hermes-agent
  - WEBUI_AUTH=${WEBUI_AUTH:-false}
depends_on:
  hermes-bridge:
    condition: service_healthy
```

Open WebUI 不直接保存 DeepSeek key。它只知道 Smart Bridge 地址和 `HERMES_API_KEY`。

### hermes-bridge

Open WebUI 上传图片时会把图片放进 OpenAI-style `image_url` content parts。DeepSeek V4 Flash 文本端点不应直接接收这些图片结构，否则会报：

```text
unknown variant `image_url`, expected `text`
```

因此 OpenDeepSeek 默认在 Open WebUI 和 Hermes 中间加 `hermes-bridge`：

```
Open WebUI → hermes-bridge → Hermes Agent → DeepSeek V4 Flash
                │
                ├─ 保存图片到 /host/OpenDeepSeek-Inputs
                ├─ OCR 中文/英文截图文字
                └─ 把 image_url 改写成纯文本路径 + OCR 摘要
```

这样普通用户可以继续上传证据图、截图、网页图；DeepSeek 仍然只负责文本推理和 Agent 规划，Hermes 负责真实文件/终端执行。

### searxng

```yaml
profiles:
  - "full"
ports:
  - "${BIND_HOST:-127.0.0.1}:8889:8080"
```

SearXNG 默认不启动。需要自托管联网搜索时再用 `--profile full`。

---

## 5. 网络与端口

```
主机（宿主机）
├── 127.0.0.1:3000 → open-webui:8080   用户入口
├── 127.0.0.1:8642 → hermes:8642       Hermes OpenAI-compatible API（调试用）
└── 127.0.0.1:8889 → searxng:8080      可选 full profile

Docker 内部网络：opendeepseek-network
├── open-webui    → hermes-bridge:8765
├── hermes-bridge → hermes:8642
├── hermes        → api.deepseek.com
└── open-webui → searxng:8080          full profile 时
```

默认 `BIND_HOST=127.0.0.1`，只允许本机访问。需要手机、Tailscale 或公网访问时，先读 [SECURITY.md](SECURITY.md)，再考虑改成 `BIND_HOST=0.0.0.0` 并启用 `WEBUI_AUTH=true`。

---

## 6. 状态与持久化

| 容器 | Docker 卷名 | 挂载路径 | 主要内容 |
|---|---|---|---|
| hermes | `hermes-data` | `/opt/data` | Memory / Skills / sessions / cron / config.yaml |
| open-webui | `open-webui-data` | `/app/backend/data` | 用户、对话、知识库、上传文件 |

执行 `docker compose down` 不会删除数据卷。执行 `docker compose down -v` 会删除数据卷，也会清空 Open WebUI 历史和 Hermes Memory。

---

## 7. 配置要点

`.env` 的核心变量：

```env
DEEPSEEK_API_KEY=sk-...
DEFAULT_MODEL=deepseek-v4-flash
HERMES_API_KEY=<random>
WEBUI_SECRET_KEY=<random>
WEBUI_AUTH=false
BIND_HOST=127.0.0.1
```

### hermes-bridge

```env
ENABLE_LIGHTWEIGHT_ROUTING=true
HERMES_AGENT_MAX_TOKENS=32768
HERMES_AGENT_STREAM=false
OPDS_HOST_DISPLAY_PREFIX=/Users/yourname
```

- `HERMES_AGENT_MAX_TOKENS` 只作用于真 Agent 任务，普通问答仍走轻量路径。
- `HERMES_AGENT_STREAM=false` 是发布前的保守默认：先让 Hermes 工具链完整执行并验证产物，再把结果交回 OpenWebUI。后续如果做了可靠的 Agent 进度事件，再考虑开启流式 Agent 状态。
- `OPDS_HOST_DISPLAY_PREFIX` 用来把容器路径 `/host/...` 转成用户电脑上的真实路径。

模型切换：

```env
DEFAULT_MODEL=deepseek-v4-pro
```

兼容说明：`deepseek-chat` / `deepseek-reasoner` 将于 2026-07-24 弃用；出于兼容，目前分别对应 `deepseek-v4-flash` 的非思考 / 思考模式。OpenDeepSeek 默认使用官方新模型名。若旧 Hermes provider 暂时不识别新名，可临时把 `DEFAULT_MODEL` 改为 `deepseek-reasoner` 兜底，但这不是长期推荐配置。

改完 `.env` 后使用：

```bash
docker compose down
docker compose up -d
./scripts/hermes-fix-model.sh deepseek-v4-pro
```

不要只用 `docker compose restart`，它不会重新加载 `.env`。

---

## 8. 验证标准

最小验证：

```bash
docker compose ps
bash scripts/smoke-test.sh
```

手动端到端验证：

```bash
HK=$(grep -m1 "^HERMES_API_KEY=" .env | cut -d= -f2-)
docker compose exec -T -e HERMES_KEY="$HK" hermes-bridge python - <<'PY'
import json, os, urllib.request

payload = {
    "model": "hermes-agent",
    "messages": [{"role": "user", "content": "只回答两个大写英文字母：OK"}],
    "max_tokens": 50,
}
req = urllib.request.Request(
    "http://localhost:8765/v1/chat/completions",
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "Authorization": "Bearer " + os.environ["HERMES_KEY"],
        "Content-Type": "application/json",
    },
)
print(urllib.request.urlopen(req, timeout=180).read().decode("utf-8"))
PY
```

如需验证图片上传链路，应从 `hermes-bridge` 发起或直接在 Open WebUI 上传图片；不要只测 Hermes 直连，因为直连不会覆盖 `image_url` 适配层。

通过标准：

- Open WebUI `http://localhost:3000` 可访问。
- Hermes `http://localhost:8642/health` 可访问。
- Smart Bridge `/health` 可访问。
- `/v1/models` 暴露 `hermes-agent`。
- `/v1/chat/completions` 有真实回复，且不是 `401` / `Error` 字符串。
- `usage.prompt_tokens > 0`，说明请求真的走过 Hermes 内核。
- Cron / Memory / Skill 至少一类能被自然语言触发。

---

## 9. 已知限制

| 限制 | 影响 | 处理 |
|---|---|---|
| Hermes 首次生成的 `config.yaml` 默认 model 不是 DeepSeek | DeepSeek API 会拒绝未知模型 | `scripts/hermes-fix-model.sh` 自动修复 |
| `WEBUI_AUTH=false` 只在空数据卷首次启动时完全生效 | 已有 Open WebUI 数据时可能仍要求登录 | 需要切家庭模式时先备份，再决定是否 `docker compose down -v` |
| Hermes Memory 默认是单实例共享 | 多人共用时记忆可能混在一起 | 家庭单用户默认可接受，团队部署需隔离实例或关闭共享记忆 |
| SearXNG 部分引擎 warning | 日志有噪音 | 不影响主流搜索，可按需调 settings |
| 修改 `.env` 后只 restart | 新变量不生效 | 用 `docker compose down && docker compose up -d` |

---

## 10. 路线

- Open WebUI Tools 一键导入，让 Cron / Memory / Skill 在 UI 中更可发现。
- Memory 可视化，让用户看到“记住了什么”。
- IM 桥接模板继续补齐钉钉、飞书、企微、QQ Bot 的最短路径。
- PWA 安装体验继续强化，降低第一次使用门槛。
