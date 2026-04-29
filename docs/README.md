# OpenDeepSeek

一键部署的本地 Agentic ChatGPT

## 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/yourusername/opendeepseek.git
cd opendeepseek

# 2. 运行安装脚本
./setup.sh
```

## 手动安装

```bash
# 1. 配置环境变量
cp .env.example .env
# 编辑 .env 填入你的 DeepSeek API Key

# 2. 启动服务
docker compose up -d

# 3. 访问 Web UI
open http://localhost:3000
```

## 特性

- 🚀 一键部署，5 分钟可用
- 🤖 真正的 Agent 能力（非角色扮演）
- 💰 极致性价比（DeepSeek API 价格仅为 GPT-4o 的 1/9）
- 📱 手机远程访问（Tailscale 内网穿透）
- 🔧 预加载编程 Skills
- 🌐 中文优先体验

## 架构

- **前端**：Open WebUI（ChatGPT-like 界面）
- **Agent 引擎**：Hermes Agent（自进化 Agent 框架）
- **LLM 后端**：DeepSeek API（OpenAI-compatible）

## 文档

- [安装指南](docs/INSTALL.md)
- [常见问题](docs/FAQ.md)
- [中国网络优化](docs/CHINA-NETWORK.md)

## 许可证

MIT
