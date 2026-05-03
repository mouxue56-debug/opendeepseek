# OpenDeepSeek 记忆融合方案

OpenDeepSeek 不应该让 OpenWebUI 和 Hermes 互相抢功能。正确做法是分层保留，再做一条轻量共享摘要。

## 结论

| 记忆/数据 | 放在哪里 | 原因 |
|---|---|---|
| 聊天历史 | OpenWebUI | 这是用户界面层的原生能力，保留即可 |
| 知识库 / 上传文件索引 | OpenWebUI | OpenWebUI 已经有成熟的 RAG、文件管理和 UI |
| 用户偏好 | Hermes Memory + 共享摘要 | Agent 和轻量问答都需要知道 |
| 常用路径 | Hermes Memory + 共享摘要 | 例如 `/host/OpenDeepSeek-Outputs`、桌面路径 |
| Cron / 后台任务 | Hermes | OpenWebUI 做不到真后台 Agent 调度 |
| Skills / 工具使用经验 | Hermes | 属于执行态能力 |
| 敏感内容、API Key、隐私文件正文 | 不写入共享摘要 | 避免扩散隐私 |

## 数据流

```text
普通问答：
OpenWebUI → Smart Bridge → 读取 /host/OpenDeepSeek-Memory/profile.md → DeepSeek V4 Flash

真任务：
OpenWebUI → Smart Bridge → Hermes Agent → Hermes Memory / Cron / Skills / 文件工具
                                      └→ 同步更新 shared memory snapshot
```

## 为什么要有共享摘要

v0.4.2 开始，OpenDeepSeek 会把普通问答直连 DeepSeek V4 Flash，避免每次闲聊都背着 Hermes 工具上下文跑。

这样速度会明显变快，但会带来一个问题：轻量路径看不到 Hermes Memory。

解决方法不是把 OpenWebUI 数据库和 Hermes 数据库强行打通，而是维护一份很小的共享摘要：

```text
/host/OpenDeepSeek-Memory/profile.md
```

Smart Bridge 在轻量问答前读取这份文件，作为系统提示的一部分注入给 DeepSeek。这样普通问答也能知道用户偏好，但不会携带整套 Agent 工具上下文。

## 写入规则

用户明确说“记住……”时，Hermes Agent 应该：

1. 使用 Hermes Memory 保存。
2. 更新 `/host/OpenDeepSeek-Memory/profile.md`。
3. 回复用户：记住了什么，写到了哪里。

共享摘要只保留稳定信息：

```markdown
# OpenDeepSeek Shared Memory

## 用户偏好
- 默认中文。
- 回答直接，少废话。
- 承诺即执行，不要只解释。

## 常用路径
- 输出目录：/host/OpenDeepSeek-Outputs

## 项目背景
- 普通问答走轻量路径，真任务走 Hermes Agent。

## 更新记录
- 2026-05-04：记录了用户偏好。
```

## 路由提醒

不要每次都解释路由。只有在这些情况提醒用户：

- 用户问“为什么不能看桌面/为什么没有 Agent 能力”。
- 用户发的是普通问答，但后续明显需要文件、提醒、记忆、图片、终端或工具。
- 任务失败，原因是请求没有进入 Hermes Agent。

推荐提示语：

```text
普通问答会走轻量路径；真要操作文件、提醒、记忆、图片和工具，会切到 Hermes Agent。你也可以在消息开头加 /agent 强制进入 Hermes。
```

## MVP 已做

- Smart Bridge 支持 `ENABLE_LIGHTWEIGHT_ROUTING=true`。
- 普通问答直连 `deepseek-v4-flash`，并默认关闭 thinking。
- 真任务、图片、文件、提醒、记忆、工具调用进入 Hermes Agent。
- Smart Bridge 读取 `/host/OpenDeepSeek-Memory/profile.md` 注入轻量问答。
- Hermes `SOUL.md` 和 `memory-bridge` skill 已写入这套规则。

## 后续可以做

- 在 OpenWebUI 里增加一个“同步到 Hermes Memory”的按钮。
- 做一个小型管理页展示共享摘要。
- 增加敏感词过滤，阻止 API Key、密码、私密正文进入共享摘要。
- 让 smoke test 覆盖“记住偏好 → 轻量问答读取偏好”的完整链路。
