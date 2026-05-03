# OpenDeepSeek 文档索引

一键部署的本地 Agentic ChatGPT，DeepSeek V4 内核。

## 快速开始

```bash
git clone https://github.com/mouxue56-debug/opendeepseek.git
cd opendeepseek
./setup.sh --web   # 浏览器安装向导：只问 1 个 API Key，其他自动智能默认
```

完成后浏览器自动打开 http://localhost:3000，**无需注册直接对话**。

## 默认架构（v0.4.2）

```
[浏览器/手机/PWA] → [Open WebUI] → [Hermes Smart Bridge] → [DeepSeek V4 轻量问答]
                                                    │
                                                    └→ [Hermes Agent] → [DeepSeek V4 真任务]
                                                       └── /host 本机文件 + Memory + Cron + Skills
```

Open WebUI 负责好用界面、聊天历史、知识库和上传；Hermes Smart Bridge 负责图片落盘 OCR 与智能路由；Hermes 负责 Agent 工具、文件/终端、长期记忆、定时任务和子代理；DeepSeek V4 负责推理。

## 文档导航

### 👶 小白必读
- [**第一次打开怎么用**](FIRST-LAUNCH.md) — 浏览器打开 :3000 看到什么 + 5 句话验证 + 排错
- [**小白使用手册**](USER-GUIDE.md) — Open WebUI 30+ 英文术语中文对照表 + 常用功能教程
- [**出错怎么办**](TROUBLESHOOT.md) — 15 个常见错误的中文大白话解决步骤
- [**样例 Prompt 集**](PROMPT-COOKBOOK.md) — 15 个中国普通用户场景，复制即用
- [**视频文案**](VIDEO-SCRIPT.md) — 为什么 OpenDeepSeek 不是聊天框，而是真 Agent
- [**数据飞轮视频拍摄稿**](VIDEO-DATA-FLYWHEEL.md) — DeepSeek、Agent、API、人和模型后训练的拍摄脚本
- [**记忆融合方案**](MEMORY-INTEGRATION.md) — Open WebUI 记忆/知识库与 Hermes Memory 如何分工互通

### 📦 部署 / 运维
- [安装指南](INSTALL.md)
- [常见问题 FAQ](FAQ.md)
- [一键部署完整指南](ONE-CLICK.md) — 各平台命令
- [路人一键部署说明](PUBLIC-DEPLOYMENT.md) — 面向第一次看到项目的普通用户
- [安全配置](SECURITY.md) — 公网部署加固清单
- [IM 桥接配置](IM-BRIDGE.md) — 钉钉/飞书/企微/邮件/QQ Bot
- [中国网络优化](CHINA-NETWORK.md)

### 🛠️ 进阶 / 开发者
- [架构深度文档](ARCHITECTURE.md) — 设计哲学 / 数据流 / 容器拓扑
- [Agent E2E Benchmark](BENCHMARK.md) — 10 个新会话 × 3 轮端到端能力验证
- [多模型协作工作流](MULTI-MODEL-WORKFLOW.md) — Kimi/Qwen/GLM/MiniMax + Codex/Claude 协作模板（可复用）
- [用 Qwen3.6 review 项目](QWEN-REVIEW.md) — OpenClaw + 阿里云 Coding Plan 合规调用
- [贡献指南](../CONTRIBUTING.md)

## 许可证

MIT License — 详见根目录 [LICENSE](../LICENSE)
