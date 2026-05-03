# OpenDeepSeek 文档索引

一键部署的本地 Agentic ChatGPT，DeepSeek V4 内核。

## 快速开始

```bash
git clone https://github.com/yourusername/opendeepseek.git
cd opendeepseek
./setup.sh   # 极简模式：只问 1 个 API Key，其他自动智能默认
```

完成后浏览器自动打开 http://localhost:3000，**无需注册直接对话**。

## 默认架构（v0.3.0）

```
[浏览器/手机/桌面 App] → [Open WebUI v0.9.2] → [DeepSeek V4 Flash]
                                     ↑
                       两层直连，简单清晰
```

可选高级层（`docker compose --profile advanced up -d`）：加 Hermes Agent 接钉钉/飞书/企微/邮件/QQ Bot 桥接。需要额外配 OpenRouter / Anthropic / Kimi 等 API key（Hermes 不原生支持 DeepSeek）。

## 文档导航

### 👶 小白必读
- [**第一次打开怎么用**](FIRST-LAUNCH.md) — 浏览器打开 :3000 看到什么 + 5 句话验证 + 排错
- [**小白使用手册**](USER-GUIDE.md) — Open WebUI 30+ 英文术语中文对照表 + 常用功能教程
- [**出错怎么办**](TROUBLESHOOT.md) — 15 个常见错误的中文大白话解决步骤
- [**样例 Prompt 集**](PROMPT-COOKBOOK.md) — 15 个中国普通用户场景，复制即用

### 📦 部署 / 运维
- [安装指南](INSTALL.md)
- [常见问题 FAQ](FAQ.md)
- [一键部署完整指南](ONE-CLICK.md) — 各平台命令
- [安全配置](SECURITY.md) — 公网部署加固清单
- [IM 桥接配置](IM-BRIDGE.md) — 钉钉/飞书/企微/邮件/QQ Bot
- [中国网络优化](CHINA-NETWORK.md)

### 🛠️ 进阶 / 开发者
- [架构深度文档](ARCHITECTURE.md) — 设计哲学 / 数据流 / 容器拓扑
- [多模型协作工作流](MULTI-MODEL-WORKFLOW.md) — Kimi/Qwen/GLM/MiniMax + Claude 协作模板（可复用）
- [用 Qwen3.6 review 项目](QWEN-REVIEW.md) — OpenClaw + 阿里云 Coding Plan 合规调用
- [贡献指南](../CONTRIBUTING.md)

## 许可证

MIT License — 详见根目录 [LICENSE](../LICENSE)
