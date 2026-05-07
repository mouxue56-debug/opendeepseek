# OpenDeepSeek 🚀

> 一键部署的本地 Agentic ChatGPT — 默认 DeepSeek V4，支持自定义 OpenAI-compatible API，中文优先，开箱即用

## ⚡ 30 秒一键部署

国际版：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

无需懂 Docker。脚本会检测系统依赖、clone 项目、打开配置向导、启动容器、打开浏览器。**默认家庭模式**：访问 http://localhost:3000 直接对话，**不需要注册**。

中国版（Gitee 入口，下载有进度和超时提示）：

```bash
curl -fL --connect-timeout 10 --max-time 120 \
  https://gitee.com/luoxueai/opendeepseek/raw/main/install-cn.sh \
  -o /tmp/opendeepseek-install-cn.sh && bash /tmp/opendeepseek-install-cn.sh
```

不要用 `bash -c "$(curl -fsSL ...)"` 作为国内推荐命令；Gitee raw 慢的时候，命令替换阶段没有任何进度，用户会以为“啥都没发生”。

当前 CN 入口已提供脚本、Gitee raw 安装入口、`docker-compose.cn.yml`、`.env.example.cn` 和网络体检；默认使用已公开可拉的上游镜像保证先跑起来。正式对外宣称完整 China Ready 前，还需要同步 GitCode、发布国内容器镜像和 OSS/COS 离线包。

当前本地产品化进度：M0-M5 已落地，包含 release gate、中国版安装骨架、国内镜像/离线包脚本、中文 Portal、Artifact Manifest、四个 OpenDeepSeek 产品模式。云端发布动作仍需要维护者手动提供账号权限并确认。

Provider 选择：小白默认填 DeepSeek API Key；高级用户可在 Portal 里切到自定义 OpenAI-compatible API（OpenRouter、本地 Ollama/LM Studio/vLLM、国内兼容平台、LiteLLM、自建网关等）。Open WebUI 仍然只连接 Smart Bridge，不需要用户手动进后台改 Connections。

→ 详细各平台一键命令见 [docs/ONE-CLICK.md](docs/ONE-CLICK.md)

> **⚠️ 安全提醒**：默认家庭模式下端口绑定到 `127.0.0.1`（仅本机访问）。如需在云服务器 / 公网部署，必须：
> 1. 在 `.env` 设置 `WEBUI_AUTH=true`（启用账号登录）
> 2. 在 `.env` 设置 `BIND_HOST=0.0.0.0`（绑定全部网卡）
> 3. 配置反向代理（Nginx / Caddy）+ HTTPS + IP 白名单或 Tailscale 隧道
>
> 详见 [docs/SECURITY.md](docs/SECURITY.md)。**永远不要在没有 auth 的情况下把服务暴露到公网。**

---

## 这是什么

OpenDeepSeek 是一个**本地部署的 AI Agent 平台** — 你可以把它理解成自己服务器上跑的 ChatGPT，但 Agent 能力是真实的（不是角色扮演）。它默认基于 DeepSeek V4 系列模型，提供完整中文体验，也允许高级用户接入自定义 OpenAI-compatible API。支持知识库、多模态、IM 桥接和后台任务调度。不需要写代码，不需要配环境，5 分钟就能跑起来。

## 它能做什么

- **写代码** — 基于你的项目知识库生成、审查、重构代码，支持多文件上下文
- **操作本机文件** — Hermes 通过 `/host` 访问你的桌面/文档目录，能真生成网页、报告、周报、脚本
- **读文档** — PDF / Word / Excel / PPT，含中文扫描件（PaddleOCR-vl 识别）
- **联网搜资料** — 内置 SearXNG 多源聚合搜索，自动抓取网页摘要
- **接入工作 IM** — 钉钉 / 飞书 / 企微 / 邮件 / QQ Bot，群里 @AI 直接提问
- **后台跑任务** — 睡前布置任务，醒来在 IM 里收结果（Cron + Subagent）
- **多模态出图** — 支持 DALL-E、Stable Diffusion、ComfyUI 工作流
- **三端使用** — 浏览器 + 桌面 App（Electron）+ 手机 PWA，数据同步

## 架构（v0.4.2 — 智能路由 + Agent 真打通）

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
              ↓ OpenAI 兼容 API（opendeepseek-auto / fast / agent / deepwork）
┌──────────────────────────────┐
│ Hermes Smart Bridge           │
│ • 图片落盘到 /host            │
│ • 中文/英文 OCR               │
│ • image_url → 文本路径摘要     │
│ • 普通问答直连 DeepSeek/Custom │
│ • 真任务自动转 Hermes Agent    │
└──────────────────────────────┘
       ↓ 普通问答             ↓ 文件/提醒/记忆/图片/工具
┌──────────────────────────────┐
│ DeepSeek / Custom API          │
│ • 轻量聊天低延迟              │
│ • 默认 DeepSeek thinking 关闭  │
└──────────────────────────────┘
                              ↓
┌──────────────────────────────┐
│ Hermes Agent v0.11 (内核层)   │
│ • Memory 跨会话记忆           │
│ • Skills 自学习扩展           │
│ • Cron 后台定时任务           │
│ • Subagent 并行执行           │
│ • 16 IM 平台桥接              │
│   (provider: deepseek/custom)  │
└──────────────────────────────┘
              ↓ LLM Provider
┌──────────────────────────────┐
│ DeepSeek V4 Flash / Pro        │
│ 或自定义 OpenAI-compatible API │
└──────────────────────────────┘
```

**四层各司其职**：
- **终端层**（Open WebUI）= 用户体验：网页/PWA/桌面 App / 知识库 / 多模态
- **智能桥接层**（Hermes Smart Bridge）= 图片落盘 OCR + 路由判断：普通问答走轻量直连，真任务进 Hermes
- **内核层**（Hermes）= Agent 大脑：Memory/Skills/Cron/Subagent，用 DeepSeek 当 LLM
- **模型层**（DeepSeek V4）= 推理引擎：1/9 GPT-4o 价格

**用户在 Open WebUI 里直接说话**：
- "你好，解释一下..." → Smart Bridge 直连轻量 Provider，少 token、快响应、支持流式
- "30 分钟后提醒我喝水" → Hermes Cron skill 真创建任务，到时推送
- "记住我喜欢咖啡" → Hermes Memory 跨会话持久化
- "看看 /host/Desktop 有什么，帮我整理方案" → Hermes file/terminal 工具真检查本机文件
- "根据这两张截图做网页 PPT" → Smart Bridge 本地解析图片，Hermes 生成文件
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

macOS 用户也可以直接双击 `OpenDeepSeek.command`。首次使用会打开浏览器配置向导；以后会自动唤起 OrbStack/Docker、轻量启动核心服务并打开 `http://localhost:3000`。如果系统拦截，先右键 `OpenDeepSeek.command` → 打开。

### 发布前 / 出错时自检

```bash
./setup.sh verify
./setup.sh doctor
./setup.sh report
./setup.sh fix   # 只做非破坏性修复：补变量、建目录，不删数据
python3 scripts/benchmark_routing.py
bash scripts/smoke-test.sh
```

`verify` 只读检查 `.env`、Docker Compose、端口、`/host` 映射和高输出预算；`doctor` 做一键诊断；`report` 生成脱敏诊断包；`benchmark_routing.py` 离线验证普通问答不会误进 Hermes、真任务不会误走普通聊天。

真实 Provider API Key / 余额 / Base URL 检查：

```bash
./setup.sh verify-live
```

统一健康检查：

```bash
./scripts/health-check.sh
```

Gitee 镜像同步和 raw 安装脚本校验：

```bash
GITEE_TOKEN=*** ./scripts/sync-gitee.sh
./scripts/sync-gitee.sh --verify-only
```

### 低内存 / 电脑变卡

默认启动现在走轻量核心服务：

```bash
./setup.sh start
```

需要 SearXNG 联网搜索时再显式开启 full profile：

```bash
./setup.sh start-full
```

释放内存：

```bash
./setup.sh stop
```

更多见 [docs/PERFORMANCE-TUNING.md](docs/PERFORMANCE-TUNING.md)。

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
- **[我应该下载哪个版本](docs/zh-CN/00-我应该下载哪个版本.md)** — Mac / Windows / Linux / 离线镜像包选择
- **[国内网络问题](docs/zh-CN/04-国内网络问题.md)** — GitHub / Docker / pip / npm / 搜索不可用时怎么办
- **[离线安装](docs/zh-CN/05-离线安装.md)** — 国内离线包、镜像包、文件权限和卸载说明
- **[填写 DeepSeek Key](docs/zh-CN/06-填写DeepSeek-Key.md)** — 获取、填写、替换 API Key 和安全注意
- **[文件权限说明](docs/zh-CN/07-文件权限说明.md)** — Agent 能访问哪里、生成文件在哪、怎么扩大授权
- **[中文文档索引](docs/zh-CN/README.md)** — 国内用户安装、离线包、Key、权限和维护者发布入口

### 📦 部署 / 运维
- [安装指南](docs/INSTALL.md) — 详细安装步骤和排错
- [常见问题 FAQ](docs/FAQ.md) — 12+ 主题分组的常见问题
- [安全配置](docs/SECURITY.md) — 公网部署加固清单 + Tailscale 推荐
- [IM 桥接配置](docs/IM-BRIDGE.md) — 钉钉 / 飞书 / 企微 / 邮件 / QQ Bot 接入
- [中国网络优化](docs/CHINA-NETWORK.md) — 镜像源、代理配置、DNS 优化
- [OpenDeepSeek CN 产品线路线图](docs/OPENDEEPSEEK-CN-ROADMAP.md) — 国内分发、离线包、Portal、产物中心规划
- [发布检查清单](docs/RELEASE-CHECKLIST.md) — release gate、人工 UI、安全和 China Ready 发布检查
- [Artifact Manifest](docs/ARTIFACT-MANIFEST.md) — 产物卡片、只读预览服务和 manifest schema
- [离线包发布流程](docs/zh-CN/离线包发布流程.md) — 国内镜像、离线包、checksum 和 OSS/COS 发布步骤
- [中文演示脚本](docs/DEMO-SCRIPT-CN.md) — 视频/README 动图/路演的演示流程

### 🛠️ 进阶 / 开发者
- [项目需求与当前进展](docs/PROJECT-REQUIREMENTS-AND-STATUS.md) — 项目初心、已验证链路和下一步
- [最终交接文档](docs/FINAL-HANDOVER.md) — M0-M6 完成内容、验证结果、启动方式和发布卡口
- [架构深度文档](docs/ARCHITECTURE.md) — 设计哲学 / 数据流 / 容器拓扑 / 扩展点
- [Goal 工作台](docs/GOALS/OPENDEEPSEEK-CN.md) — M0-M6 分阶段落地中国版产品线
- [贡献指南](CONTRIBUTING.md) — 提 PR 流程 + commit message 规范
- [用 Qwen3.6 review 项目](docs/QWEN-REVIEW.md) — OpenClaw + 阿里云 Coding Plan 合规调用
- [多模型协作工作流](docs/MULTI-MODEL-WORKFLOW.md) — Kimi/Qwen/GLM/MiniMax + Codex/Claude 协作模板（可复用）

## ⚠️ 重要提示：模型迁移

本项目默认使用 `deepseek-v4-flash`。`deepseek-chat` 和 `deepseek-reasoner` 将于 **2026-07-24 弃用**；出于兼容，二者目前分别对应 `deepseek-v4-flash` 的非思考 / 思考模式。OpenDeepSeek 优先使用官方新模型名；若某个旧 Hermes provider 暂时不识别新名，可临时用兼容别名兜底，但项目文档和默认配置不再推荐旧名。

## 贡献

PR 欢迎。Discord 社区即将上线。

## License

MIT License
