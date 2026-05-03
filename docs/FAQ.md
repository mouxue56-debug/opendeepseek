# OpenDeepSeek 常见问题（FAQ）

> 本文档面向简体中文用户，涵盖模型、部署、功能、集成、隐私等高频问题。按主题分组，点击目录快速跳转。

**目录**

- [模型相关](#模型相关)
- [部署相关](#部署相关)
- [功能相关](#功能相关)
- [IM 集成](#im-集成)
- [隐私与多用户](#隐私与多用户)
- [进阶](#进阶)

---

## 模型相关

### Q: deepseek-chat 在 2026-07-24 退役，对我有什么影响？怎么迁移？

**影响**：2026-07-24 起，`deepseek-chat`（V3）和 `deepseek-reasoner`（R1）将停止服务，调用会返回 `410 Gone` 或降级到 V4-flash。

**迁移步骤**：

1. 修改 `.env` 中的模型别名：
   ```bash
   # 旧配置（即将失效）
   DEFAULT_MODEL=deepseek-chat

   # 新配置（推荐）
   DEFAULT_MODEL=deepseek-v4-flash
   # 或需要深度推理时
   # DEFAULT_MODEL=deepseek-v4-pro
   ```
2. 重启容器：
   ```bash
   docker compose down && docker compose up -d
   ```
3. 若之前保存了 `deepseek-chat` 的预设提示词，建议在新模型下重新测试效果（V4 的指令遵循能力更强，部分旧提示词可能需要精简）。

> 退役公告详见：[DeepSeek 官方通知](https://platform.deepseek.com)（登录后查看「模型生命周期」页面）。

---

### Q: deepseek-v4-flash 和 v4-pro 怎么选？价格和能力对比？

| 维度 | v4-flash（默认） | v4-pro |
|------|------------------|--------|
| **定位** | 日常对话、快速响应、工具调用 | 深度推理、复杂分析、长文本 |
| **输入价格** | ¥0.50 / 百万 tokens | ¥2.00 / 百万 tokens |
| **输出价格** | ¥2.00 / 百万 tokens | ¥8.00 / 百万 tokens |
| **上下文长度** | 64K | 128K |
| **多轮 tool calling** | 稳定 | 更稳定（复杂链路首选） |
| **典型场景** | 客服问答、知识库检索、简单代码 | 财务分析、论文阅读、架构设计 |

**选择建议**：

- 90% 的场景用 `v4-flash` 足够，响应更快、成本更低。
- 当任务涉及 **>5 步工具链**、**>32K 长文本**、**数学/逻辑推理** 时，切换到 `v4-pro`。
- 在对话界面点击模型下拉框即可实时切换，无需重启。

---

### Q: 多轮 tool calling 偶尔失败（issue #1244）怎么办？

**现象**：AI 调用工具后未等待结果就继续发言，或工具返回后 AI "失忆"。

**原因**：V4-flash 在复杂多轮工具链（>3 轮）时，偶发注意力漂移。V4-pro 更稳定，但成本更高。

**解决方案**（按优先级）：

1. **升级到最新镜像**（已含针对 #1244 的提示词修复）：
   ```bash
   docker compose pull && docker compose up -d
   ```
2. **简化工具链**：将 5 步工具调用拆分为 2 步，中间让 AI 总结一次。
3. **切换 v4-pro**：在对话顶部下拉框切到 `v4-pro`，复杂任务更稳定。
4. **手动兜底**：在 `.env` 开启调试日志，失败时手动重试：
   ```bash
   HERMES_DEBUG=true  # 查看完整 tool calling 链路
   ```

> 该问题为已知上游限制，DeepSeek 团队已在 V4 后续版本中优化。关注 [issue #1244](https://github.com/opendeepseek/opendeepseek/issues/1244) 获取进展。

---

## 部署相关

### Q: 能跑在 4 核 4G 的 VPS 吗？资源占用多少？

**可以跑，但建议 4 核 8G。**

| 组件 | 最低配置 | 推荐配置 | 说明 |
|------|---------|---------|------|
| **Open WebUI** | 2 核 2G | 2 核 4G | 前端 + 后端，无 GPU 需求 |
| **Hermes Agent** | 1 核 1G | 2 核 2G | 默认启动，提供 Memory / Skills / Cron / Subagent / IM 桥接 |
| **SearXNG**（可选） | 1 核 1G | 1 核 2G | 自托管搜索，无外部依赖 |
| **总计（默认）** | **3 核 3G** | **4 核 6G** | Hermes + Open WebUI |
| **总计（full）** | **4 核 4G** | **4 核 8G** | 额外含 SearXNG |

**4 核 4G 实测表现**：

- 单用户流畅使用 ✅
- 3 人同时对话偶发卡顿 ⚠️
- 开启 SearXNG 后内存吃紧 ⚠️

**优化建议（低配机器）**：

```bash
# 只启动核心服务，不启用本地搜索后端
docker compose up -d

# 需要自托管联网搜索时再启用 full profile
docker compose --profile full up -d
```

---

### Q: 怎么改默认端口（3000 / 8642 已占用）？

修改 `docker-compose.yml` 中的端口映射：

```yaml
services:
  open-webui:
    ports:
      - "127.0.0.1:3002:8080"   # 原 3000，避开 onboarding 的 3001
  hermes:
    ports:
      - "127.0.0.1:8643:8642"   # 原 8642
  searxng:
    ports:
      - "127.0.0.1:8890:8080"   # 如启用 full profile
```

然后重启：

```bash
docker compose down && docker compose up -d
```

**验证**：

```bash
curl http://localhost:3002          # Open WebUI 应返回 HTML
curl http://localhost:8643/health   # Hermes 应返回健康状态
```

> 若使用反向代理（Nginx/Caddy），记得同步更新 upstream 端口。

---

### Q: 数据备份怎么做？哪些目录是数据卷？

**持久化数据卷**（必须备份）：

| 路径 | 内容 | 备份方式 |
|------|------|---------|
| `./data/webui` | 用户账号、对话历史、设置 | `rsync` / `tar` |
| `./data/hermes` | Agent 记忆、工具配置、知识库索引 | `rsync` / `tar` |
| `./data/searxng` | 搜索偏好（如启用） | 可选 |

**一键备份脚本**：

```bash
#!/bin/bash
BACKUP_DIR="/backup/opendeepseek/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 停止服务保证数据一致性
docker compose down

# 备份数据卷
cp -r ./data "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/" 2>/dev/null || true
cp docker-compose.yml "$BACKUP_DIR/"

# 压缩
tar czf "$BACKUP_DIR.tar.gz" -C "$(dirname $BACKUP_DIR)" "$(basename $BACKUP_DIR)"
echo "备份完成: $BACKUP_DIR.tar.gz"

# 重启
docker compose up -d
```

**恢复**：

```bash
tar xzf 20260115_120000.tar.gz
cd 20260115_120000
cp -r data /path/to/opendeepseek/
cp .env docker-compose.yml /path/to/opendeepseek/
cd /path/to/opendeepseek && docker compose up -d
```

> 建议设置 cron 每日自动备份到对象存储（如阿里云 OSS、AWS S3）。

---

## 功能相关

### Q: 知识库怎么用？支持哪些文档格式？

**使用方式**：

1. 进入对话界面 → 点击「知识库」图标 → 上传文件或选择已有库。
2. 支持 **多库混合检索**：同时勾选「产品手册」+「内部 FAQ」，AI 会自动合并答案。
3. 在 `.env` 调整检索策略：
   ```bash
   KNOWLEDGE_TOP_K=5           # 每次检索召回 5 条片段
   KNOWLEDGE_SIMILARITY=0.75   # 相似度阈值（0-1）
   ```

**支持格式**：

| 格式 | 处理方式 | 备注 |
|------|---------|------|
| `.txt` / `.md` / `.json` | 直接分块索引 | 推荐，效果最佳 |
| `.pdf` | 文本层提取 / OCR  fallback | 见下一条 FAQ |
| `.docx` / `.xlsx` | 解析为纯文本 | 表格转为结构化文本 |
| `.epub` / `.html` | 提取正文 | 自动过滤导航/广告 |
| 图片（`.png` / `.jpg`） | PaddleOCR-vl 识别 | 需开启 OCR 组件 |

> 不支持 `.pptx`、扫描版 PDF（无文本层）、加密 PDF。

---

### Q: 怎么上传中文 PDF 让 AI 读？（提到 PaddleOCR-vl）

**分两种情况**：

**情况 1：PDF 有文本层**（可复制粘贴）

- 直接上传，系统自动提取文本，无需额外配置。

**情况 2：扫描版 / 图片 PDF**（无法复制）

- 需要开启 PaddleOCR-vl 组件：
  ```bash
  # .env
  ENABLE_PADDLEOCR=true
  PADDLEOCR_MODEL=paddleocr-vl-latest  # 支持中英文混合识别
  ```
- 重启后上传 PDF，系统会自动调用 OCR 识别图片中的文字。

**中文优化建议**：

```bash
# 提高中文识别准确率
PADDLEOCR_LANG=ch_sim+en    # 简体中文 + 英文
PADDLEOCR_DPI=300           # 扫描件建议 300dpi 以上
```

**限制**：

- 单文件上限 50MB，超过请拆分。
- 手写体识别率约 85%，印刷体 >95%。
- 竖排古籍支持实验性，识别率可能下降。

---

### Q: 联网搜索怎么开？需要 API Key 吗？

**无需 API Key**，OpenDeepSeek 内置 **SearXNG** 自托管搜索引擎。

**开启步骤**：

```bash
docker compose --profile full up -d
```

启动后 SearXNG 在 Docker 内网中供 Open WebUI 使用；如需调试搜索页面，访问 `http://localhost:8889`。

**工作原理**：

```
用户提问 → SearXNG 聚合 Google/Bing/Brave 等结果 → 取 Top-5 网页 → 提取正文 → 注入 prompt → DeepSeek 回答
```

**自定义搜索引擎**（可选）：

```bash
# .env
SEARXNG_ENGINES=google,bing,brave,duckduckgo   # 默认聚合
SEARXNG_SAFE_SEARCH=2                          # 严格安全过滤
```

> SearXNG 完全本地运行，搜索请求不走任何第三方 API，因此 **零费用、零 key 需求**。但搜索质量依赖你的服务器网络环境（能否访问 Google/Bing）。

---

## IM 集成

### Q: 怎么接入钉钉/飞书/企微？

OpenDeepSeek 提供 **IM Bridge** 组件，统一接入国内主流办公平台。

**接入方式**：

| 平台 | 协议 | 配置位置 | 文档 |
|------|------|---------|------|
| **钉钉** | 钉钉机器人 Webhook + Stream | `.env` | [IM-BRIDGE.md#1-钉钉机器人](IM-BRIDGE.md#1-钉钉机器人) |
| **飞书 (Lark)** | 飞书机器人 Webhook / 事件订阅 | `.env` | [IM-BRIDGE.md#2-飞书机器人](IM-BRIDGE.md#2-飞书机器人) |
| **企业微信** | 企微机器人 Webhook | `.env` | [IM-BRIDGE.md#3-企业微信wecom](IM-BRIDGE.md#3-企业微信wecom) |

**通用配置模板**：

```bash
# .env
IM_BRIDGE_ENABLED=true
IM_BRIDGE_PLATFORM=dingtalk    # 或 lark / wecom

# 各平台具体凭证（从对应后台获取）
DINGTALK_WEBHOOK_URL=https://oapi.dingtalk.com/robot/send?access_token=xxx
DINGTALK_SECRET=xxx            # 加签密钥（可选）

LARK_WEBHOOK_URL=https://open.feishu.cn/open-apis/bot/v2/hook/xxx
LARK_APP_ID=cli_xxx
LARK_APP_SECRET=xxx
```

**效果**：

- 群聊中 @机器人 即可对话
- 支持私聊、群聊、富文本回复
- 与 Web 端共享同一知识库和记忆

> 详细步骤、截图指引、常见问题见 **[IM-BRIDGE.md](IM-BRIDGE.md)**。

---

### Q: 为什么不支持 Telegram？

**原因：中国网络环境限制。**

Telegram 服务在中国大陆及部分地区无法直接访问，需要：

1. 服务器部署在海外（香港/新加坡/日本）
2. 或配置代理/VPN 穿透

这会增加部署复杂度，且不符合 OpenDeepSeek **「一键本地部署」** 的设计目标。

**替代方案**：

- 如需海外 IM 支持，可手动扩展：
  ```bash
  # 社区贡献的 Telegram Bridge（实验性）
  docker compose -f docker-compose.yml -f docker-compose.telegram.yml up -d
  ```
- 或部署在海外 VPS，直接访问 Telegram Bot API。

> 如果你有稳定的海外网络环境，欢迎提交 PR 完善 Telegram 支持。

---

## 隐私与多用户

### Q: 我的对话数据存在哪里？发到云上吗？

**数据存储原则：本地优先，最小上传。**

| 数据类型 | 存储位置 | 是否上云 | 说明 |
|---------|---------|---------|------|
| **对话历史** | 本地 `./data/webui` | ❌ 不上云 | 你的服务器硬盘 |
| **知识库文件** | 本地 `./data/hermes` | ❌ 不上云 | 向量索引本地构建 |
| **用户账号** | 本地 SQLite | ❌ 不上云 | 无云端同步 |
| **调用 DeepSeek API** | DeepSeek 服务器 | ✅ 上传 prompt | 仅上传当前对话内容，不含历史 |

**关键说明**：

- **本地组件**（Open WebUI、SearXNG，以及可选的 Hermes）全部自托管，数据不出服务器。
- **DeepSeek API 调用**时，prompt 和上下文会发送到 DeepSeek 服务器进行处理，这是使用云端模型的必要条件。
- 若需 **完全离线**，可替换为本地模型（如 Ollama + Llama 3），但能力会下降。

**隐私增强配置**：

```bash
# .env
# 开启后，API 调用不携带历史对话（每次独立请求，保护上下文隐私）
HERMES_STATELESS_MODE=true

# 本地日志不记录用户消息内容
LOG_LEVEL=warning
```

---

### Q: 能不能给家人开账号？是共享还是隔离？

**支持多用户，数据完全隔离。**

**开启方式**：

1. 管理员进入「设置」→「用户管理」→「开启注册」或「手动创建账号」。
2. 每个用户拥有：
   - 独立的对话历史
   - 独立的知识库权限
   - 独立的 API 用量统计

**权限模型**：

| 角色 | 权限 |
|------|------|
| **管理员** | 修改系统设置、管理用户、查看所有对话 |
| **普通用户** | 仅查看自己的对话和知识库 |
| **访客** | 临时对话，不保存历史 |

**给家人开账号的建议**：

```bash
# 创建家人账号（管理员后台）
# 用户名: dad / mom / sister
# 角色: 普通用户（默认）

# 可选：共享家庭知识库
# 在「知识库设置」→「权限」→ 添加用户到「家庭共享」组
```

> 默认情况下，用户之间 **无法看到对方的对话**，管理员也需在「审计模式」下才能查看。

---

## 进阶

### Q: Hermes Agent 是什么？为什么不直接用 Open WebUI 接 DeepSeek？

Hermes 是 OpenDeepSeek 的 Agent 内核。v0.4.0 起默认路径是：

```
用户 → Open WebUI → Hermes Agent → DeepSeek V4
```

Open WebUI 负责网页/PWA/桌面体验；Hermes 负责 Memory、Skills、Cron、Subagent 和 IM 桥接；DeepSeek V4 负责推理。直接让 Open WebUI 接 DeepSeek 只能得到普通聊天，无法保证“提醒我喝水”这类请求真的进入 Hermes Cron skill。

**关键数据流**：

```
普通网页对话：
用户 → Open WebUI → Hermes → DeepSeek → Hermes 工具/记忆 → Open WebUI

IM/Cron：
钉钉/飞书用户 @bot → Hermes → DeepSeek → Cron/Memory/Skill → 推送回 IM
```

**默认启动**：

```bash
docker compose up -d
```

Hermes 使用原生 `deepseek` provider，复用 `.env` 里的 `DEEPSEEK_API_KEY`。

---

### Q: 默认架构和 full profile 的区别？

| 对比项 | 默认部署 | full profile |
|--------|---------|-----------------|
| **启动命令** | `docker compose up -d` | `docker compose --profile full up -d` |
| **容器数** | 2（Hermes + Open WebUI） | 3（+ SearXNG） |
| **内存占用** | ~3G（最低） | ~4G（最低） |
| **LLM provider** | Hermes 原生 deepseek provider | 同默认 |
| **普通网页对话** | ✅ | ✅ |
| **IM 机器人（钉钉/飞书）** | ✅（填入对应凭证后启用） | ✅ |
| **定时任务 / Cron 推送** | ✅ | ✅ |
| **联网搜索后端** | 不启动本地 SearXNG | 启动 SearXNG |
| **何时选用** | 绝大多数个人 / 团队用户 | 需要自托管联网搜索 |

---

### Q: 我的 API key 会泄露吗？

**设计上不会，但需遵守部署规范。**

**防护机制**：

| 层面 | 措施 |
|------|------|
| **存储** | API key 写入 `.env`，**绝不进入 git**（`.gitignore` 已排除） |
| **传输** | 服务端内部使用（Open WebUI / Hermes），前端不可见；日志自动脱敏 |
| **隔离** | 多用户场景下，普通用户无法读取 `.env` 或系统环境变量 |

**验证你的 key 是否安全**：

```bash
# 1. 确认 .env 不在 git 中
git check-ignore .env   # 应输出 .env

# 2. 确认日志无泄露
docker logs opendeepseek-hermes 2>&1 | grep -i "sk-" || echo "未发现明文 key"

# 3. 确认前端无法获取
curl http://localhost:3000/api/config | grep -i "api_key" || echo "前端不暴露 key"
```

**风险场景（用户责任）**：

- ❌ 将 `.env` 截图发到公开群聊
- ❌ 在公共 VPS 上开放 3000 端口且无防火墙
- ❌ 使用弱密码且开启外网注册

**应急**：若怀疑泄露，立即到 [DeepSeek 控制台](https://platform.deepseek.com) 重置 key 并更新 `.env`。

---

> 还有其他问题？提交 [GitHub Issue](https://github.com/opendeepseek/opendeepseek/issues) 或查看 [完整文档目录](README.md)。
