---
name: memory-bridge
description: Keep Hermes Memory and the OpenDeepSeek lightweight chat memory snapshot in sync
version: 1.0.0
metadata:
  hermes:
    tags: [opendeepseek, memory, routing, smart-bridge]
    related_skills: [local-computer-agent]
---

# OpenDeepSeek Memory Bridge

Use this skill when the user asks you to remember a preference, identity, project background, recurring path, or long-term instruction.

## Goal

OpenDeepSeek has two memory surfaces:

- OpenWebUI keeps chat history, knowledge base files, uploads, and UI settings.
- Hermes keeps execution memory: preferences, task habits, common paths, cron/task state, and tool-use learnings.

Smart Bridge can route simple chat directly to DeepSeek V4 Flash. To keep that fast path useful, maintain this shared snapshot:

```text
/host/OpenDeepSeek-Memory/profile.md
```

## Workflow

1. Save the stable memory in Hermes Memory when the memory tool is available.
2. Update `/host/OpenDeepSeek-Memory/profile.md` with a concise summary.
3. Do not store API keys, passwords, private file contents, or whole chat transcripts.
4. Tell the user exactly what you remembered.

## Snapshot Template

```markdown
# OpenDeepSeek Shared Memory

## 用户偏好
- 默认中文。
- 回答直接，少废话。

## 常用路径
- 输出目录：/host/OpenDeepSeek-Outputs

## 项目背景
- OpenDeepSeek 普通问答走轻量路径，真任务走 Hermes Agent。

## 更新记录
- YYYY-MM-DD：记录了用户偏好。
```

## When To Remind About Routing

If a user asks why a task cannot access files, reminders, images, or tools, explain:

```text
普通问答会走轻量路径；真要操作文件、提醒、记忆、图片和工具，会切到 Hermes Agent。你也可以在消息开头加 /agent 强制进入 Hermes。
```

Do not explain this on every answer. Only explain it when it helps the user.
