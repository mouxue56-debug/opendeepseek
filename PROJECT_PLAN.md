# OpenDeepSeek 项目规划

## 项目目标
一键部署的本地 Agentic ChatGPT 替代品
- DeepSeek API（便宜、OpenAI-compatible）
- Open WebUI（成熟前端，手机友好）
- Hermes Agent（自进化 Agent，工具执行）

## 核心需求
1. 一键安装：setup.sh 自动处理 Docker/依赖
2. 手机访问：Tailscale 内网穿透
3. 预加载技能：编程/Cloud 相关 skills
4. 安全：API Key 只在 .env，不提交 git

## 调研重点
- Hermes Agent 最新版本（0.10.0？）与 DeepSeek API 兼容性
- Open WebUI 官方 Hermes 集成文档
- 社区一键部署方案（Docker Compose）
- 预加载 skills 最佳实践

## 时间线
- T0: 项目创建 + 规划（现在）
- T1: 蜂群调研（10分钟内）
- T2: 圆桌讨论（多模型评估）
- T3: 输出可执行方案

## 风险点
- Hermes Agent 容器化成熟度
- DeepSeek API tool calling 格式兼容性
- 跨平台（Win/Mac/Linux）一致性
