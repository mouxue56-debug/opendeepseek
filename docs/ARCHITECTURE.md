# OpenDeepSeek 架构深度文档

> 面向开发者、贡献者和想要 fork 本项目的人。  
> 版本：v0.3.0 | 最后更新：2026-05-03

---

## 1. 设计哲学

### 为什么默认两层直连，而不是三层？

OpenDeepSeek v0.3.0 的核心设计判断是：**默认路径越短越可靠**。

**v0.3.0 默认架构：Open WebUI 直连 DeepSeek**

直接把 DeepSeek API 接入 Open WebUI，你得到的是一个功能完整、零中间故障点的对话平台：

- **Open WebUI 的核心价值完全保留**：多用户 RBAC / 对话历史 / 知识库 RAG / 多模态上传 / Web+PWA+桌面三端 / 管理 UI
- **零依赖启动**：一个容器，30 秒内跑起来，无需配置 Agent 密钥
- **消除 v0.2 的 401 bug**：Hermes v0.11 内置支持 8 个 LLM provider，**没有 DeepSeek**。强行把 Hermes 加在中间只会引入 401 认证失败和调试负担，而非带来价值

**为什么 Hermes 从默认层移到 advanced profile？**

Hermes 的真正价值在于 **IM 桥接 + Cron + Memory**，而不是做 LLM proxy。v0.3.0 把它放到 `profiles: ["advanced"]`，仅在用户有以下需求时才启用：

- 需要钉钉/飞书/企微/邮件/QQ Bot/Matrix 等 16 个 IM 平台桥接
- 需要 Cron 定时任务或跨会话 Memory
- Hermes 启用时，使用 OpenRouter / Anthropic / Kimi 等它原生支持的 provider，不再强行走 DeepSeek

**为什么不直接 Hermes CLI/IM（绕过 Open WebUI）？**

Hermes 是一个强大的 Agent 内核，但它的原生界面是命令行和 IM 机器人。如果你只用 Hermes，你会失去：

- **Web/PWA/桌面 App 三端**：Hermes CLI 没有浏览器界面，没有移动端 PWA，没有 Electron App
- **多用户 RBAC**：Hermes 默认是单用户的，团队共享场景需要复杂的多端口部署
- **知识库 RAG**：Open WebUI 内置 9 种向量数据库适配、文档分块、混合检索，Hermes 不提供
- **多模态上传**：图片/PDF/Office 文件的拖拽上传、在线预览
- **管理 UI**：模型配置、用户管理、使用统计

**结论：默认直连保证零故障点，Hermes 作为可选层在真正需要 IM 桥接时才引入。这是 OpenDeepSeek v0.3.0 的核心设计原则。**

---

## 2. 架构总览

### 默认架构（两层直连）

```
┌──────────────────────────────────────────────────────────┐
│                      终端层                               │
│   ┌──────────┐   ┌──────────────┐   ┌───────────────┐   │
│   │  浏览器   │   │ 桌面 App     │   │  手机 PWA     │   │
│   │ (任意)   │   │ (Electron)   │   │ (Service SW)  │   │
│   └──────────┘   └──────────────┘   └───────────────┘   │
└───────────────────────────┬──────────────────────────────┘
                            │ HTTP :3000
┌───────────────────────────▼──────────────────────────────┐
│                    体验层 (Open WebUI v0.9.2)              │
│                                                          │
│   • 多用户登录 / RBAC 权限管理                             │
│   • 对话历史 / 书签 / 分享                                 │
│   • 知识库 RAG（9 种向量库 + 混合检索）                    │
│   • 多模态：PDF / Office / 图片 / 扫描件 OCR               │
│   • Code Interpreter（ENABLE_CODE_INTERPRETER=true）      │
│   • 模型管理 / Admin Panel / 使用统计                      │
│   • 桌面 App (Electron) + 手机 PWA                        │
│                                                          │
│   内部监听：:8080  对外映射：:3000                         │
└───────────────────────────┬──────────────────────────────┘
                            │ HTTPS api.deepseek.com/v1
                            │ Authorization: Bearer DEEPSEEK_API_KEY
                            │ (OPENAI_API_BASE_URL 直连)
┌───────────────────────────▼──────────────────────────────┐
│                    模型层 (DeepSeek V4)                    │
│                                                          │
│   DEFAULT_MODEL=deepseek-chat                            │
│   端点：https://api.deepseek.com/v1                       │
│   备选：deepseek-reasoner（推理更强，成本更高）             │
└──────────────────────────────────────────────────────────┘

                    ┌──────────────────┐
                    │  SearXNG（可选）  │
                    │  --profile full  │
                    │  :8889 → :8080   │
                    └──────────────────┘
```

**默认启动命令：**
```
[终端] → [Open WebUI v0.9.2] → [DeepSeek V4 api.deepseek.com]
```

### 可选 Advanced Profile（IM 桥接 + Cron + Memory）

启用条件：`docker compose --profile advanced up -d`

```
[终端] → [Open WebUI] → [DeepSeek] （普通对话，直连）
                  ↓
              [Hermes v0.11] （IM/Cron/Memory，用 OpenRouter 等）
                  ↓
              [钉钉/飞书/企微/邮件/QQ Bot/Matrix]
```

> **注意**：Advanced profile 中 Hermes 使用 OpenRouter / Anthropic / Kimi 等它原生支持的 provider，不走 DeepSeek。

---

## 3. 数据流：一次请求的完整生命周期

以用户在浏览器输入"帮我总结今天的新闻"为例，追踪从前端到模型再返回的全路径：

| 步骤 | 发生了什么 | 时间估计 |
|------|-----------|---------|
| **1. 用户输入** | 浏览器向 Open WebUI `:3000` 发起 WebSocket/SSE 连接，携带消息体和会话 ID | `<2ms` |
| **2. Open WebUI 路由** | WebUI 将消息封装为 OpenAI-compatible `POST /v1/chat/completions`，直接发往 `https://api.deepseek.com/v1`（`OPENAI_API_BASE_URL`），附上 `DEEPSEEK_API_KEY` Bearer token | `<5ms` |
| **3. DeepSeek API 接收** | DeepSeek 解析请求，按 `model` 字段路由到对应模型，启用 streaming 响应 | `~200ms` TTFB |
| **4. 流式回传** | DeepSeek 逐 token 返回，Open WebUI 直接接收 SSE chunked transfer | `~1-3s` 完整响应 |
| **5. Open WebUI 渲染** | WebUI 实时渲染 Markdown，完成后写入对话历史数据库（SQLite/向量库） | `<50ms` |

**关键路径**：从用户回车到看到第一个字，关键延迟来自第 3 步 DeepSeek API 的 TTFB（约 200ms）。Open WebUI 本身处理开销不超过 10ms，对用户体验影响微乎其微。

---

## 4. 容器拓扑详解

### 4.1 hermes 容器（仅 advanced profile）

```yaml
image: nousresearch/hermes-agent:v2026.4.23
profiles:
  - "advanced"
```

**默认不启动**。仅在执行 `docker compose --profile advanced up -d` 时才拉起。设计理由：Hermes v0.11 不支持 DeepSeek 作为原生 LLM provider，强行默认启动只会引入 401 认证失败；将其限定在 advanced profile 保证默认部署零故障。

镜像 tag **固定到日期版本**（`v2026.4.23`），不使用 `latest`。原因：Hermes 的 Memory schema 和 Skills API 在 minor 版本间可能不兼容，固定版本保证升级由人工控制，避免数据静默损坏。

**关键环境变量说明（advanced profile）：**

- `OPENAI_API_KEY=${OPENROUTER_API_KEY}`：Advanced profile 中 Hermes 使用 OpenRouter / Anthropic / Kimi 等它原生支持的 provider，不再映射 DeepSeek key。
- `OPENAI_API_BASE_URL=https://openrouter.ai/api/v1`：指向 OpenRouter（或其他 Hermes 支持的 provider）。
- `API_SERVER_KEY=${HERMES_API_KEY}`：其他服务访问 Hermes 时使用的 Bearer token，与上游 provider key 相互独立。

**healthcheck 为什么用 python3 urllib 而非 curl：**

```yaml
test: ["CMD-SHELL", "python3 -c \"import urllib.request; urllib.request.urlopen('http://localhost:8642/health')\" 2>/dev/null || exit 1"]
```

`nousresearch/hermes-agent` 镜像基于精简的 Python 基础镜像构建，**镜像内没有安装 curl**。Python 的 `urllib` 是标准库，无需额外安装，是唯一可靠的选择。

**数据卷 `/opt/data` 持久化内容：**

- `memory.md`：用户的长期记忆摘要（跨会话的偏好、事实、上下文）
- `skills/`：自定义 Skill Markdown 文件
- `sessions/`：对话 session 状态（用于 Subagent 断点续传）
- `cron/`：定时任务定义文件

### 4.2 open-webui 容器

```yaml
image: ghcr.io/open-webui/open-webui:0.9.2
ports:
  - "3000:8080"
```

容器内部 Uvicorn 监听 `:8080`，通过 `3000:8080` 映射到主机。选择 3000 而非直接 8080，是因为 8080 是常见的代理/开发服务器端口，冲突概率更高。

**v0.3.0 中不再有 `depends_on hermes`：**

默认部署直连 DeepSeek，Open WebUI 启动时无需等待 Hermes 就绪。`OPENAI_API_BASE_URL=https://api.deepseek.com/v1` 直接指向外部 API，消除了启动竞态问题。

**`extra_hosts: host.docker.internal:host-gateway`：**

在 Linux 宿主机上，`host.docker.internal` 不像 macOS/Windows Docker Desktop 那样自动解析。这行配置将其显式映射到宿主机 IP，使 Open WebUI 在 Linux 上也能访问宿主机的其他服务（如用户自建的本地 Ollama 或自定义工具）。

### 4.3 searxng 容器

```yaml
profiles:
  - "full"
ports:
  - "8889:8080"
```

SearXNG 默认**不启动**，需要 `--profile full` 或 `setup.sh` 中选择"中文优化模式"才会拉起。这样设计的原因是 SearXNG 会增加约 200MB 内存占用，对只需要纯对话的用户是不必要的负担。

端口选用 **8889** 而非常见的 8888，原因是在 OrbStack（macOS 上流行的 Docker 替代品）环境中，8888 端口被 tinyproxy 服务占用，部署时会产生端口冲突。调试过程中发现这一问题后，改为 8889 规避冲突。

---

## 5. 网络与端口

```
主机（宿主机）—— 默认部署
└── :3000  →  open-webui:8080   （Open WebUI 对外访问入口）

主机（宿主机）—— 启用 --profile advanced 后新增
└── :8642  →  hermes:8642       （Hermes API，IM 桥接入口）

主机（宿主机）—— 启用 --profile full 后新增
└── :8889  →  searxng:8080      （SearXNG 搜索）

Docker 内部网络：opendeepseek-network（bridge driver）
├── open-webui  →  https://api.deepseek.com/v1  （直连外部 API）
├── open-webui  →  hermes:8642    （仅 advanced profile 启用时）
└── hermes      →  searxng:8080   （若 SearXNG 已启用）
```

**为什么 `OPENAI_API_BASE_URL` 必须带 `/v1`：**

```
OPENAI_API_BASE_URL=https://api.deepseek.com/v1
```

Open WebUI 在构造请求时，会直接在 `OPENAI_API_BASE_URL` 后追加路径（如 `/chat/completions`、`/models`），而**不会**自动插入 `/v1` 前缀。若不带 `/v1`，实际请求会发到 `https://api.deepseek.com/chat/completions`，404 报错。这是 Open WebUI 的设计约定，文档中有说明但容易遗漏。

---

## 6. 状态与持久化

| 容器 | Docker 卷名 | 挂载路径 | 主要内容 | 备份方法 |
|------|------------|---------|---------|---------|
| hermes | `hermes-data` | `/opt/data` | Memory.md / Skills / sessions / cron | `docker run --rm -v hermes-data:/data -v $(pwd):/backup alpine tar czf /backup/hermes-backup.tar.gz /data` |
| open-webui | `open-webui-data` | `/app/backend/data` | 用户账号 / 对话历史 / 知识库 / 向量数据库 / 上传文件 | `docker run --rm -v open-webui-data:/data -v $(pwd):/backup alpine tar czf /backup/webui-backup.tar.gz /data` |

两个卷均为 Docker named volume，存储在 Docker 数据目录下（macOS：`~/Library/Containers/com.docker.docker/Data/vms/`，Linux：`/var/lib/docker/volumes/`）。执行 `docker compose down`（不带 `-v`）不会删除数据卷，数据安全。

---

## 7. 安全模型

**密钥分层隔离：**

```
用户浏览器
    │  不知道任何 API Key
    ▼
Open WebUI（持有 HERMES_API_KEY）
    │  只能访问 Hermes Gateway
    ▼
Hermes Gateway（持有 DEEPSEEK_API_KEY）
    │  只能访问 DeepSeek API
    ▼
DeepSeek API
```

- `DEEPSEEK_API_KEY` 仅存在于 `hermes` 容器的环境变量中，Open WebUI 容器**不知道**这个 key，浏览器端更不会接触到。
- `HERMES_API_KEY` 和 `WEBUI_SECRET_KEY` 由 `setup.sh` 在首次安装时使用 `openssl rand -hex 32` 自动生成，每次部署都是独立的 64 位随机字符串，不可预测。
- `.env` 文件包含所有密钥，**不纳入 git 版本控制**（`.gitignore` 已排除），不会意外泄漏到代码仓库。
- 容器以非 root 用户运行（Hermes 和 Open WebUI 镜像内置了 USER 指令），减小容器逃逸的影响范围。SearXNG 在 Compose 中通过 `cap_drop: ALL` 进一步限制 Linux capabilities（完整 profile 中可配置）。

---

## 8. 扩展点

### 8.1 接入新 IM 平台

Hermes 已支持 16 个 IM 平台（钉钉、飞书、企微、邮件、QQ Bot、Matrix 等），**无需修改代码**，只需在 `.env` 中填入对应的 Bot Token：

```bash
# 示例：启用飞书
FEISHU_APP_ID=cli_xxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxxxx
```

然后 `docker compose restart hermes`，Hermes 会自动启动对应的 IM 桥接 worker。

### 8.2 添加自定义 Skill

在 Hermes 数据卷下创建 Markdown 文件：

```bash
# 进入 hermes 容器
docker exec -it opendeepseek-hermes bash

# 创建 Skill 文件
cat > /opt/data/skills/my_skill.md << 'EOF'
# 股票查询
触发词：查股票、股价、行情
...
EOF
```

Hermes 会在下次请求时自动加载，无需重启。

### 8.3 添加 Open WebUI 自定义 Tool

登录 Open WebUI → Admin Panel → Tools → 上传 Python 文件。Open WebUI 的 Tool 系统支持任意 Python 函数，可以调用外部 API、本地数据库或其他服务。

### 8.4 切换语言模型

修改 `.env` 中的 `DEFAULT_MODEL`，然后重启 hermes 容器：

```bash
# 切换到 V4 Pro（推理更强）
DEFAULT_MODEL=deepseek-v4-pro

docker compose restart hermes
```

如需切换完全不同的模型服务商，修改 `OPENAI_API_BASE_URL` 指向兼容 OpenAI API 的端点即可（如 Groq、Together AI、本地 Ollama）。

---

## 9. 已知限制

| 限制 | 影响范围 | 状态 |
|-----|---------|-----|
| **Hermes 不支持 DeepSeek 作为原生 LLM provider**（v0.11 内置 8 个 provider 没有 deepseek） | 尝试用 Hermes 中转 DeepSeek 会收到 401 认证失败 | OpenDeepSeek v0.3.0 默认 Open WebUI 直连 DeepSeek，Hermes 仅作为 IM 桥接层（用 OpenRouter 等其他 provider） |
| DeepSeek reasoner 多轮 `tool_calls` ~21% 概率退化为纯文本 | 使用 reasoner 模型且需要复杂 tool use 的场景 | 上游 bug，deepseek-chat 无此问题 |
| Hermes 默认共享 Memory，无多用户隔离 | 多人共用同一 advanced profile 部署时 Memory 互相污染 | 需通过多 Profile + 多端口解决，默认家庭单用户场景不受影响 |
| SearXNG 部分引擎加载失败 | ahmia、torch、wikidata 等小众引擎报 warning | 上游 SearXNG bug，不影响主流搜索（Google/Bing/DuckDuckGo），可忽略 |
| `docker compose restart` 不重载 `.env` | 修改 `.env` 后错用 restart 会不生效 | 需 `docker compose down && docker compose up -d`（已在文档中说明） |

---

## 10. 性能与资源参考

| 指标 | 默认部署（仅 open-webui） | advanced profile（+hermes） | 满载状态（大文档 RAG）|
|-----|---------|---------------------|---------------------|
| RAM 占用 | ~450 MB（webui ~400 / overhead ~50）| ~650 MB（+hermes ~200）| ~1.2 GB |
| CPU | <1%（基本静止）| <1%（基本静止）| ~30%（单核，主要在向量化） |
| 磁盘（镜像）| ~4 GB（初始拉取）| ~5 GB（+hermes 镜像）| 不变 |
| 磁盘（数据增长）| — | — | ~50 MB/天（重度使用） |
| API 费用 | — | — | DeepSeek chat $0.14/1M input tokens（约 GPT-4o 的 1/9）|

**默认部署仅需 1 个容器**（open-webui ~400MB），比 v0.2 节省约 150MB Hermes 启动开销。最低可在 2 GB RAM 的机器（如低配 VPS、树莓派 5）上运行默认版。启用 advanced profile（+hermes）后推荐 4 GB 以上；启用 SearXNG 后峰值 RAM 约 1.5 GB，推荐 8 GB 以上机器。

---

## 11. 未来路线（Wave 3+）

- **Cron/Memory 暴露为 Open WebUI Tool**：让 Web 用户也能通过聊天界面创建定时任务（"明天早上 8 点提醒我"），目前仅 IM 用户可以通过自然语言触发 Cron。
- **多 Profile 模板生成器**：为团队版部署提供一键生成多 Profile 配置的脚本，每个用户独立的 Memory 空间和 RBAC 角色。
- **独立 telegram-watchdog**：Telegram polling 在网络抖动时可能静默卡死而不报错，计划添加一个轻量级 sidecar 容器，检测到 polling 停止时自动重启 Hermes 的 Telegram 桥接 worker。
- **向量数据库可选后端**：Open WebUI 支持 Chroma/Qdrant/Milvus 等，默认使用内置 SQLite 向量检索。大规模知识库（>10 万文档）场景下，可通过环境变量切换到独立的 Qdrant 容器。

---

*本文档描述的是 OpenDeepSeek v0.3.0 版本的架构。如有变更，请以 `docker-compose.yml` 和 `CHANGELOG.md` 为准。*
