# OpenDeepSeek 🚀

> 一键部署的本地 Agentic ChatGPT — DeepSeek V4 内核，中文优先，开箱即用

## ⚡ 30 秒一键部署

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yourusername/opendeepseek/main/install.sh)
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
- **读文档** — PDF / Word / Excel / PPT，含中文扫描件（PaddleOCR-vl 识别）
- **联网搜资料** — 内置 SearXNG 多源聚合搜索，自动抓取网页摘要
- **接入工作 IM** — 钉钉 / 飞书 / 企微 / 邮件 / QQ Bot，群里 @AI 直接提问
- **后台跑任务** — 睡前布置任务，醒来在 IM 里收结果（Cron + Subagent）
- **多模态出图** — 支持 DALL-E、Stable Diffusion、ComfyUI 工作流
- **三端使用** — 浏览器 + 桌面 App（Electron）+ 手机 PWA，数据同步

## 架构

```
┌──────────────────────────────┐
│ 📱 PWA  🖥️ 桌面  💻 浏览器   │
└──────────────────────────────┘
              ↓
┌──────────────────────────────┐
│ Open WebUI v0.9.2 (终端层)    │
│ • 多用户登录 / RBAC          │
│ • 中文 PDF / 知识库 RAG      │
│ • 多模态 / 桌面 App / PWA    │
└──────────────────────────────┘
              ↓ OpenAI API
┌──────────────────────────────┐
│ Hermes Agent v0.11 (内核层)   │
│ • Memory + Skills + Cron     │
│ • 钉钉/飞书/企微/邮件/QQ      │
└──────────────────────────────┘
              ↓
┌──────────────────────────────┐
│ DeepSeek V4 Flash (模型层)    │
└──────────────────────────────┘
```

三层分离：终端层负责交互，内核层负责 Agent 逻辑和外部集成，模型层提供推理能力。你可以单独升级任何一层而不影响其他层。

## 5 分钟快速开始

### 一键安装（推荐）

```bash
git clone https://github.com/your-org/opendeepseek.git
cd opendeepseek
./setup.sh
# 按提示填入 DeepSeek API Key，完成
```

### 手动安装

```bash
git clone https://github.com/your-org/opendeepseek.git
cd opendeepseek
cp .env.example .env
# 编辑 .env，填入 DEEPSEEK_API_KEY
docker compose up -d
# 访问 http://localhost:3000
```

## 核心特性

| 特性 | 说明 |
|---|---|
| 🌐 三端打通 | PWA + 桌面 App + 浏览器，随时随地使用 |
| 🇨🇳 中文优先 | 30 语言界面 / PaddleOCR-vl 中文 PDF / SearXNG 中文搜索 |
| 🤖 真 Agent | Memory 长期记忆 / Skills 工具扩展 / Cron 定时任务 / Subagent 子代理 |
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

- [安装指南](docs/INSTALL.md) — 详细安装步骤和排错
- [常见问题 FAQ](docs/FAQ.md) — 安装失败、网络问题、模型报错
- [IM 桥接配置](docs/IM-BRIDGE.md) — 钉钉 / 飞书 / 企微 / QQ 接入教程
- [中国网络优化](docs/CHINA-NETWORK.md) — 镜像源、代理配置、DNS 优化

## ⚠️ 重要提示：模型迁移

本项目默认使用 `deepseek-v4-flash`。旧的 `deepseek-chat` 和 `deepseek-reasoner` 已于 **2026-07-24 退役**，请勿继续使用。升级方法：在 `.env` 中将 `MODEL_NAME` 改为 `deepseek-v4-flash` 或 `deepseek-v4`，然后 `docker compose restart`。

## 贡献

PR 欢迎。Discord 社区即将上线。

## License

MIT License
