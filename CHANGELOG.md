# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added
- LICENSE（MIT）
- CHANGELOG.md（本文件）
- CONTRIBUTING.md 贡献者指南
- docs/ARCHITECTURE.md 深度架构文档（设计哲学 / 数据流 / 容器拓扑 / 状态持久化 / 扩展点）
- `.github/workflows/ci.yml` CI 工作流（5 jobs：docker config / shellcheck / markdown link check / yamllint / docs existence）
- `.github/markdown-link-check.json` 链接检查配置

## [0.2.0] - 2026-04-29

### 架构 Pivot

从初版 MVP（v0.1.0）的 Hermes-only 设想转向 **Open WebUI 终端 × Hermes Agent 内核 × DeepSeek V4 模型**三层架构。基于 30 天社区调研 + 能力对比矩阵的决策。

### Added
- `docker-compose.yml`：三服务（hermes / open-webui / 可选 searxng）+ healthcheck + IM 7 平台注释模板
- `setup.sh`：6 阶段一键部署（环境检查 / 配置询问 / .env 生成 / 启动服务 / 健康检查 / 访问信息）+ China mode 选项
- `README.md`：项目门面重写，三层 ASCII 架构图 + 5 分钟上手指南
- `.env.example`：完整模板，IM/Webhook 全部 opt-in 注释
- `.gitignore`：分块完善（环境/Docker/IDE/OS/日志/用户自定义）
- `docs/INSTALL.md`：详细安装 / 升级 / 卸载 / 排错（7 节）
- `docs/FAQ.md`：12+ 中文 FAQ 按主题分组（模型 / 部署 / 功能 / IM / 隐私 / 多用户 / 进阶）
- `docs/IM-BRIDGE.md`：5 平台接入指南（钉钉 / 飞书 / 企微 / 邮件 / QQ Bot），含 4 家邮箱 SMTP 服务器表
- `docs/CHINA-NETWORK.md`：Docker 镜像加速 / 兜底服务清单 / GitHub clone 加速
- `scripts/smoke-test.sh`：7 项端到端验证（.env / 容器状态 / Hermes /health / Open WebUI / /v1/models / 真实 LLM 调用 / 桥接验证）

### Fixed (Sonnet 10 轮端到端 debug，11 个 bug)

**🔴 阻断级（不修则跑不起来）**
- `command: gateway run` 缺失 → hermes 不进 API gateway 模式
- hermes 镜像内无 curl → healthcheck 永远 unhealthy → open-webui 永远不启动；改用 `python3 urllib`
- `searxng/` 目录不存在 → bind mount 失败；预创建
- searxng image tag `2024.12.16-0` 不存在于 Docker Hub → 改为 `2026.4.28-ed5955a5c`

**🟠 影响级**
- `DEFAULT_MODEL` 硬编码而非 `${DEFAULT_MODEL}` 变量插值
- searxng 主机端口 8888 被 OrbStack tinyproxy 占用 → 改为 8889

**🟡 边缘 / 文档**
- `setup.sh` SKIP_CONFIG 路径 `grep|cut` 未去 trailing space → `tr -d '[:space:]'` + `${var:-fallback}`
- `docs/` 内部链接带多余 `docs/` 前缀（`docs/docs/xxx` 误解析）
- `docs/FAQ.md` 锚链接 `#钉钉` 不匹配 GFM anchor 格式
- README 与 docs 中端口 `:8080` 写错（实际 `:3000`）
- `smoke-test.sh` 第 5 项查 "deepseek" 字串，但 hermes 暴露 `"id": "hermes-agent"` 作为 proxy 模型 ID → 改查 OpenAI compat 结构

### Changed
- 默认模型 `deepseek-chat` → `deepseek-v4-flash`（旧模型 2026-07-24 退役）
- 镜像 tag 全部 pin（不再 `:latest` / `:main`）：
  - `nousresearch/hermes-agent:v2026.4.23`
  - `ghcr.io/open-webui/open-webui:0.9.2`
  - `searxng/searxng:2026.4.28-ed5955a5c`
- IM 桥接精选中国友好 5 个：钉钉 / 飞书 / 企微 / 邮件 / QQ Bot（弃 Telegram / WhatsApp / iMessage）
- 数据卷挂载点 `/root/.hermes` → `/opt/data`（Hermes 0.0.6 标准）

### Validated
- `bash scripts/smoke-test.sh` 端到端 7/7 PASS（含真实 DeepSeek V4 Flash 调用）
- 容器间网络互通：`docker exec open-webui curl hermes:8642/health` ✅
- `setup.sh` 双路径验证（首次配置 + SKIP_CONFIG reuse）
- `docker compose --profile full up` SearXNG 启用验证

### Known Issues
- DeepSeek V4 Pro 多轮 tool_calls ~21% 概率退化为纯文本（上游 issue #1244）
- SearXNG 几个非关键引擎（ahmia / torch / wikidata）加载失败（上游 SearXNG bug，不影响核心搜索）
- Hermes 多用户隔离需要 Profiles + 多端口（默认家庭版共享 Memory）

## [0.1.0] - 2026-04-27

### Added
- 初始项目骨架（PROJECT_PLAN.md）
- 初版 docker-compose.yml（含未验证的镜像名）
- 初版 setup.sh（基础流程）
- 初版 README.md（项目方案文档化）

[Unreleased]: https://github.com/mouxue56-debug/opendeepseek/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/mouxue56-debug/opendeepseek/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/mouxue56-debug/opendeepseek/releases/tag/v0.1.0
