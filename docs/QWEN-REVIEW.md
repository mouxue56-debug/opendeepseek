# 用 OpenClaw + Qwen3.6 Review OpenDeepSeek 项目

> 合规指南 — 阿里云 Coding Plan 用户适用

---

## 1. 为什么需要这份文档

阿里云 Model Studio **Coding Plan**（`sk-sp-` 前缀 API key）是专为编程辅助场景设计的订阅套餐，使用条款明确限制：

- **只能在编程工具内交互式使用**（如 Claude Code、OpenClaw）
- **禁止脚本化、批量、无人值守的 API 调用**

这意味着你不能写一个 Python 脚本遍历项目文件然后批量调 `qwen-coder-plus`，但你完全可以打开 OpenClaw，把文件内容粘贴进 chat，让模型逐文件 review——后者是完全合规的交互式使用。

本文档的目的就是告诉你**合规路径怎么走**，以及如何把 qwen3.6 接入 OpenClaw 用于 OpenDeepSeek 项目的 review 工作。

---

## 2. 配置 qwen3.6 到 OpenClaw

### 2.1 检查现有配置

```bash
# 查看当前已配置的 qwen 相关模型
openclaw models list | grep -i qwen
```

如果输出里已有 `coding-plan-intl/qwen3.5-plus`（fallback#4），说明 provider 已经配好，只需要追加 qwen3.6 的 model alias。

### 2.2 添加 qwen3.6 alias

```bash
# provider 已存在时，只需设置 model alias（跳过前两行）
openclaw config set 'providers.coding-plan-intl.apiKey' 'sk-sp-xxxxxxxx'
openclaw config set 'providers.coding-plan-intl.baseUrl' 'https://coding-intl.dashscope.aliyuncs.com/v1'

# 注册 qwen36 alias
openclaw config set 'models.qwen36.provider' 'coding-plan-intl'
openclaw config set 'models.qwen36.id' 'qwen3-coder-plus'
openclaw config set 'models.qwen36.alias' 'qwen36'
```

验证配置是否生效：

```bash
openclaw models list | grep qwen36
```

> ⚠️ **安全提醒**：`sk-sp-` key 绝对不要进 git 提交历史。如果你在终端里明文输入过 API key，用以下命令删除对应的 shell history 记录：
>
> ```bash
> history | grep sk-sp-   # 找到行号
> history -d <行号>        # 删除那行（zsh 用 fc -e - <行号>）
> ```

---

## 3. 用 qwen3.6 做 OpenDeepSeek Review（合规路径）

以下三种方式均为合规的**交互式调用**（人在场、手动触发）。

### 方法 A：交互式 chat（推荐）

适合多文件、需要上下文连贯的综合 review。

```bash
cd /path/to/opendeepseek
openclaw chat --model qwen36
```

进入 chat 后，粘贴以下 prompt：

```
请 review 以下 OpenDeepSeek 项目文件，给出改进建议（每个建议附文件路径和具体改动）：

1. docker-compose.yml
2. setup.sh
3. install.sh
4. scripts/smoke-test.sh
5. README.md

重点关注：
- 跨平台兼容性（macOS / Linux / WSL2）
- 安全性（API key 处理 / 网络暴露 / 容器安全）
- 用户体验（错误提示 / 进度显示 / 失败处理）
- 边缘情况（端口冲突 / Docker 没装 / 网络断开）

逐文件给建议，每个建议给：影响等级（高/中/低）+ 具体修改内容（diff 风格）。
```

然后逐个把文件内容粘贴进去（`cat docker-compose.yml` 复制输出，粘进 chat）。

### 方法 B：单次 query（快速问一个问题）

适合只想针对某个文件快速得到反馈。

```bash
openclaw infer --model qwen36 --prompt "$(cat docker-compose.yml)
请 review 这个 docker-compose.yml，找出潜在 bug 和安全问题。"
```

### 方法 C：端到端诊断 session

适合希望 qwen3.6 保持上下文、分步深入分析的场景。

```bash
openclaw chat --model qwen36
```

进入 chat 后开场白：

```
启动一个新的 review session。我会逐个粘贴 OpenDeepSeek 项目的核心文件，请你逐个 review。
开始：第一个文件是 docker-compose.yml，内容如下：
<paste content>
```

每轮粘贴一个文件，qwen3.6 会保持上下文累积分析。

---

## 4. Review 之后实施改进

qwen3.6 给出建议后，**由你决定哪些 apply**。实施方式：

- **简单改动**：直接编辑对应文件（`vim` / VS Code / 任意编辑器）
- **复杂改动**：把 diff 粘回 Claude Code（这个会话），让 Claude Code 帮你落地到代码库

建议按影响等级排优先级：先处理「高」，再处理「中」，「低」看时间。

---

## 5. ToS 红线（绝对不要做的事）

❌ **禁止**：
- 用 `sk-sp-` key 写脚本批量处理文件或批量调用 API
- 用 `sk-sp-` key 做生产服务的后端（放进 docker-compose 或 .env 供服务调用）
- 用 `sk-sp-` key 做无人值守的 cron job / CI pipeline 调用
- 把 `sk-sp-` key 提交进 git（任何分支，包括临时分支）

✅ **允许**：
- 在 OpenClaw / Claude Code 里交互式 chat
- 手动触发、人在场的代码 review
- 学习 / 调试 / 写代码（你自己看着屏幕操作）

> 阿里云会监测异常调用模式：突发大量请求、连续秒级调用、无对话上下文的请求。触发风控轻则限速，重则封号，Coding Plan 订阅费不退。

---

## 6. 备选方案

如果你不想用 qwen3.6 做 review，或者遇到 API 问题，可以用：

| 方法 | 模型 | 适用场景 |
|---|---|---|
| Claude Code（本会话） | claude-opus / sonnet | 项目同会话 review，上下文最完整 |
| Codex CLI | gpt-5.5 | 命令行 review，OpenAI 计划用户 |
| Cursor | 多 model 可选 | IDE 内 review，视觉体验好 |
| OpenClaw | kimi / glm / minimax / sonnet / opus 任选 | 同 OpenClaw 换其他模型，provider 配置复用 |

---

## 7. 当前 OpenDeepSeek 已知可改进点（Opus self-review 输出）

让 qwen3.6 做增量 review 时，以下问题已经被记录，可以作为上下文告诉它"这些已知，看看还有什么新的"：

- [ ] Hermes 对外暴露的 model id 是 `hermes-agent`，不够友好（建议改为 `OpenDeepSeek (DeepSeek V4 Flash)`）
- [x] `install.sh` 和 `README.md` 里的 GitHub 路径已统一为 `mouxue56-debug/opendeepseek`
- [ ] `CONTRIBUTING.md` 只有中文，缺英文版（国际贡献者不友好）
- [ ] 没有 systemd（Linux）/ launchd（macOS）自启脚本，重启电脑后服务需要手动恢复
- [ ] `scripts/smoke-test.sh` 第 7 项需要登录 token，自动化 CI 路径不完整
- [ ] `README.md` 缺截图 / 演示 GIF，首次访问体验缺乏视觉引导

把这个列表贴给 qwen3.6，让它在这些之上继续挖，覆盖率会更高。

---

*最后更新：2026-04-29*
