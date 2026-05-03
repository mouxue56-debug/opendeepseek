# OpenDeepSeek 🚀

> 一键部署的本地 Agentic ChatGPT — DeepSeek V4 内核，中文优先，开箱即用

## ⚡ 30 秒一键部署

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

无需懂 Docker，自动检测系统 + 安装 + 启动 + 打开浏览器。**默认家庭模式**：访问 http://localhost:3000 直接对话，**不需要注册**。

→ 详细各平台一键命令见 [docs/ONE-CLICK.md](docs/ONE-CLICK.md)

> **⚠️ 安全提醒**：默认家庭模式下端口绑定到 `127.0.0.1`（仅本机访问）。如需在云服务器 / 公网部署，必须：
> 1. 在 `.env` 设置 `WEBUI_AUTH=true`（启用账号登录）
> 2. 在 `.env` 设置 `BIND_HOST=0.0.0.0`（绑定全部网卡）
> 3. 配置反向代理（Nginx / Caddy）+ HTTPS + IP 白名单或 Tailscale 隧道
>
> 详见 [docs/SECURITY.md](docs/SECURITY.md)。**永远不要在没有 auth 的情况下把服务暴露到公网。**

---

## 这是什么

OpenDeepSeek 是一个**本地部署的 AI Agent 平台** — 你可以把它理解成自己服务器上跑的 ChatGPT，但 Agent 能力是真实的（不是角色扮演）。它基于 DeepSeek V4 系列模型（价格是 GPT-4o 的 1/9），提供完整的中文体验，支持知识库、多模态、IM 桥接和后台任务调度。不需要写代码，不需要配环境，5 分钟就能跑起来。

## 它能做什么

- **写代码** — 基于你的项目知识库生成、审查、重构代码，支持多文件上下文
- **操作本机文件** — Hermes 通过 `/host` 访问你的桌面/文档目录，能真生成网页、报告、周报、脚本
- **读文档** — PDF / Word / Excel / PPT，含中文扫描件（PaddleOCR-vl 识别）
- **联网搜资料** — 内置 SearXNG 多源聚合搜索，自动抓取网页摘要
- **接入工作 IM** — 钉钉 / 飞书 / 企微 / 邮件 / QQ Bot，群里 @AI 直接提问
- **后台跑任务** — 睡前布置任务，醒来在 IM 里收结果（Cron + Subagent）
- **多模态出图** — 支持 DALL-E、Stable Diffusion、ComfyUI 工作流
- **三端使用** — 浏览器 + 桌面 App（Electron）+ 手机 PWA，数据同步

## 架构（v0.4.0 — 三件套真正打通）

```
┌──────────────────────────────┐
│ 📱 PWA  🖥️ 桌面  💻 浏览器   │
└──────────────────────────────┘
              ↓
┌──────────────────────────────┐
│ Open WebUI v0.9.2 (终端层)    │
│ • 多用户登录 / RBAC          │
│ • 中文 PDF / 知识库 RAG      │
│ • 联网搜索 / 代码执行         │
│ • 多模态 / 桌面 App / PWA    │
│ • 6 个 Hermes Tools 桥接      │
└──────────────────────────────┘
              ↓ OpenAI 兼容 API（hermes-agent model）
┌──────────────────────────────┐
│ Hermes Agent v0.11 (内核层)   │
│ • Memory 跨会话记忆           │
│ • Skills 自学习扩展           │
│ • Cron 后台定时任务           │
│ • Subagent 并行执行           │
│ • 16 IM 平台桥接              │
│   (provider: deepseek 原生)   │
└──────────────────────────────┘
              ↓ DeepSeek API
┌──────────────────────────────┐
│ DeepSeek V4 Flash / Pro       │
│ api.deepseek.com              │
└──────────────────────────────┘
```

**三层各司其职**：
- **终端层**（Open WebUI）= 用户体验：网页/PWA/桌面 App / 知识库 / 多模态
- **内核层**（Hermes）= Agent 大脑：Memory/Skills/Cron/Subagent，用 DeepSeek 当 LLM
- **模型层**（DeepSeek V4）= 推理引擎：1/9 GPT-4o 价格

**用户在 Open WebUI 里直接说话**：
- "30 分钟后提醒我喝水" → Hermes Cron skill 真创建任务，到时推送
- "记住我喜欢咖啡" → Hermes Memory 跨会话持久化
- "看看 /host/Desktop 有什么，帮我整理方案" → Hermes file/terminal 工具真检查本机文件
- "同时帮我对比这 5 个" → Hermes Subagent 并行分析

✨ **可选**：`docker compose --profile full up -d` 加 SearXNG（联网搜索后端）

## 5 分钟快速开始

### 极简版（推荐小白）

```bash
git clone https://github.com/mouxue56-debug/opendeepseek.git
cd opendeepseek
./setup.sh --web
# 只需粘贴一次 DeepSeek API Key，其他全部自动智能默认
```

完成后浏览器自动打开 http://localhost:3000，**直接对话不用注册**。

macOS 用户也可以直接双击 `OpenDeepSeek.command`，它会自动打开浏览器配置向导。

### 高级版（懂技术的用户）

```bash
./setup.sh --advanced
# 完整 5 项配置询问：模型 / 中文模式 / IM 占位 / 部署模式 / API Key
```

### 手动安装（最低控制）

```bash
git clone https://github.com/mouxue56-debug/opendeepseek.git
cd opendeepseek
cp .env.example .env
# 编辑 .env，填入 DEEPSEEK_API_KEY
docker compose up -d
```

## 核心特性

| 特性 | 说明 |
|---|---|
| 🌐 三端打通 | PWA + 桌面 App + 浏览器，随时随地使用 |
| 🇨🇳 中文优先 | 30 语言界面 / PaddleOCR-vl 中文 PDF / SearXNG 中文搜索 |
| 🤖 真 Agent | Memory 长期记忆 / Skills 工具扩展 / Cron 定时任务 / Subagent 子代理 |
| 💻 本机文件权限 | `/host` 映射到用户家目录，可生成网页/报告/周报等真实文件 |
| 💰 极致性价比 | DeepSeek V4 Flash 仅 $0.14/1M tokens，GPT-4o 价格的 1/9 |
| 🔌 IM 桥接 | 钉钉 / 飞书 / 企微 / 邮件 / QQ Bot，群里 @AI 即可对话 |
| 📚 知识库 | RAG 检索 + 9 种向量数据库 + 5 种 OCR 引擎 |
| 🎨 多模态 | DALL-E / Stable Diffusion / ComfyUI / TTS / STT |
| 🔒 隐私本地 | 全容器化部署，数据不离开你的机器 |

## 系统要求

- Docker 20.10+ / Docker Compose v2
- 4GB RAM / 10GB 磁盘空间
- DeepSeek API Key（[platform.deepseek.com](https://platform.deepseek.com) 申请，新用户送 10 元余额）

## 文档

### 👶 小白必读（不懂技术也能看懂）
- **[小白使用手册](docs/USER-GUIDE.md)** — 30 秒上手 + Open WebUI 30+ 英文术语对照表 + 常用功能怎么用
- **[出错怎么办](docs/TROUBLESHOOT.md)** — 15 个常见错误的中文大白话排错指南
- **[样例 Prompt 集](docs/PROMPT-COOKBOOK.md)** — 15 个中国普通用户场景（写周报/翻译/旅游攻略...）复制即用
- **[一键部署完整指南](docs/ONE-CLICK.md)** — macOS / Linux / Windows WSL2 各平台命令

### 📦 部署 / 运维
- [安装指南](docs/INSTALL.md) — 详细安装步骤和排错
- [常见问题 FAQ](docs/FAQ.md) — 12+ 主题分组的常见问题
- [安全配置](docs/SECURITY.md) — 公网部署加固清单 + Tailscale 推荐
- [IM 桥接配置](docs/IM-BRIDGE.md) — 钉钉 / 飞书 / 企微 / 邮件 / QQ Bot 接入
- [中国网络优化](docs/CHINA-NETWORK.md) — 镜像源、代理配置、DNS 优化

### 🛠️ 进阶 / 开发者
- [架构深度文档](docs/ARCHITECTURE.md) — 设计哲学 / 数据流 / 容器拓扑 / 扩展点
- [贡献指南](CONTRIBUTING.md) — 提 PR 流程 + commit message 规范
- [用 Qwen3.6 review 项目](docs/QWEN-REVIEW.md) — OpenClaw + 阿里云 Coding Plan 合规调用
- [多模型协作工作流](docs/MULTI-MODEL-WORKFLOW.md) — Kimi/Qwen/GLM/MiniMax + Codex/Claude 协作模板（可复用）

## ⚠️ 重要提示：模型迁移

本项目默认使用 `deepseek-v4-flash`。旧的 `deepseek-chat` 和 `deepseek-reasoner` 已于 **2026-07-24 退役**，请勿继续使用。升级方法：在 `.env` 中将 `MODEL_NAME` 改为 `deepseek-v4-flash` 或 `deepseek-v4`，然后 `docker compose restart`。

## 贡献

PR 欢迎。Discord 社区即将上线。

## License

MIT License
