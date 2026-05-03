# OpenDeepSeek 架构深度文档

> 面向开发者、贡献者和想要 fork 本项目的人。  
> 版本：v0.4.0 | 最后更新：2026-05-03

---

## 1. 设计哲学

OpenDeepSeek 的默认架构不是“Open WebUI + 任意 LLM”，而是三件套：

```
Open WebUI → Hermes Agent → DeepSeek V4
```

三层各司其职：

- **Open WebUI**：用户体验层，提供网页、PWA、桌面 App、知识库、上传、多用户管理。
- **Hermes Agent**：Agent 内核层，提供 Memory、Skills、Cron、Subagent、IM 桥接和工具调度。
- **DeepSeek V4**：模型层，提供 `deepseek-v4-flash` / `deepseek-v4-pro` 推理能力。

项目初心是让用户在 Open WebUI 里说“30 分钟后提醒我喝水”，请求真的进入 Hermes Cron skill，而不是只让模型口头答应。Hermes 必须在默认链路中，否则 Memory、Cron、Skills、Subagent 都会退化成文档里的愿景。

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
│   • OPENAI_API_BASE_URL=http://hermes:8642/v1              │
└───────────────────────────┬──────────────────────────────┘
                            │ Docker 内网 :8642
┌───────────────────────────▼──────────────────────────────┐
│              Hermes Agent v2026.4.23（内核层）             │
│   • Memory / Skills / Cron / Subagent / IM Bridge          │
│   • HERMES_INFERENCE_PROVIDER=deepseek                     │
│   • DEFAULT_MODEL=deepseek-v4-flash                        │
│   • 对外暴露 hermes-agent model 给 Open WebUI              │
└───────────────────────────┬──────────────────────────────┘
                            │ HTTPS api.deepseek.com
┌───────────────────────────▼──────────────────────────────┐
│                    DeepSeek V4（模型层）                   │
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

以用户在 Open WebUI 输入“明天早上 8 点提醒我提交周报”为例：

| 步骤 | 发生了什么 | 关键点 |
|---|---|---|
| 1 | 浏览器向 Open WebUI `:3000` 发送消息 | 用户只面对 Web/PWA/桌面体验层 |
| 2 | Open WebUI 调用 `http://hermes:8642/v1/chat/completions` | 模型 id 是 `hermes-agent` |
| 3 | Hermes 解析请求、加载 SOUL.md、判断是否需要工具 | Cron/Memory/Skill 在这里生效 |
| 4 | Hermes 用原生 `deepseek` provider 调 DeepSeek V4 | 使用 `.env` 中的 `DEEPSEEK_API_KEY` |
| 5 | 如需提醒，Hermes 创建 Cron 任务并持久化 | 不是模型口头承诺 |
| 6 | Hermes 返回结果，Open WebUI 渲染并保存对话 | 用户仍在熟悉的聊天界面里 |

这条路径是 smoke test 必须验证的核心路径。只检查网页能打开不够，必须确认 Hermes → DeepSeek 有真实 token usage，并且 Skills 能被触发。

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
  - OPENAI_API_BASE_URL=http://hermes:8642/v1
  - OPENAI_API_KEY=${HERMES_API_KEY}
  - WEBUI_NAME=OpenDeepSeek
  - DEFAULT_MODELS=hermes-agent
  - WEBUI_AUTH=${WEBUI_AUTH:-false}
depends_on:
  hermes:
    condition: service_healthy
```

Open WebUI 不直接保存 DeepSeek key。它只知道 Hermes 网关地址和 `HERMES_API_KEY`。

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
├── 127.0.0.1:8642 → hermes:8642       Hermes OpenAI-compatible API
└── 127.0.0.1:8889 → searxng:8080      可选 full profile

Docker 内部网络：opendeepseek-network
├── open-webui → hermes:8642
├── hermes     → api.deepseek.com
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

模型切换：

```env
DEFAULT_MODEL=deepseek-v4-pro
```

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
curl -sS http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer $HK" \
  -H "Content-Type: application/json" \
  -d '{"model":"hermes-agent","messages":[{"role":"user","content":"用一个汉字回答：你好"}],"max_tokens":50}'
```

通过标准：

- Open WebUI `http://localhost:3000` 可访问。
- Hermes `http://localhost:8642/health` 可访问。
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
