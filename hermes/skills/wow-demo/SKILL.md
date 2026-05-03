---
name: wow-demo
description: OpenDeepSeek default wow demos for video, onboarding, and first-run user delight
version: 1.0.0
metadata:
  hermes:
    tags: [opendeepseek, demo, video, onboarding, wow]
    related_skills: [local-computer-agent, video-script-flywheel]
---

# OpenDeepSeek Wow Demo

Use this skill when the user asks for a demo, showcase, first-run example, or "show me what you can do".

## Demo 1: Desktop Butler

User prompt:

```text
请查看 /host/Desktop，但不要移动或删除任何文件。先按类型总结我的桌面有什么，再给我一个整理方案，并把方案写到 /host/OpenDeepSeek-Outputs/desktop-cleanup-plan.md
```

Expected behavior:

1. Use terminal/file tools to inspect `/host/Desktop`.
2. Group by file type and obvious purpose.
3. Write a cleanup plan file.
4. Do not move/delete anything without confirmation.

## Demo 2: One-Minute Personal Website

User prompt:

```text
请在 /host/OpenDeepSeek-Outputs/site 里生成一个单文件中文个人主页 index.html，主题是「我用 DeepSeek V4 + Hermes 做个人 AI 助理」。要求手机端好看，可直接打开。
```

Expected behavior:

1. Create the directory.
2. Write `index.html`.
3. Include responsive CSS.
4. Tell the user the file path.

## Demo 3: Weekly Report Machine

User prompt:

```text
请读取 /host/Desktop 或 /host/Documents 里和本周工作有关的文件名，不读取正文，帮我生成一份周报草稿到 /host/OpenDeepSeek-Outputs/weekly-report.md
```

Expected behavior:

1. Inspect file names only unless the user asks to read content.
2. Infer possible work streams.
3. Generate a polished Chinese weekly report draft.

## Demo 4: Video Script From Messy Voice Notes

User prompt:

```text
我会粘贴一段语音转录。请把它整理成 3 分钟中文视频脚本：开头钩子、痛点、解决方案、演示镜头、结尾号召，并保存到 /host/OpenDeepSeek-Outputs/video-script.md
```

Expected behavior:

1. Turn messy transcript into a clean narrative.
2. Keep the user's personal voice.
3. Add camera direction and screen recording cues.

## Demo 5: Real Reminder

User prompt:

```text
请创建一个 10 分钟后的提醒：回来检查 OpenDeepSeek 手机上是否好用。请实际使用 cron 工具创建。
```

Expected behavior:

1. Use the cronjob tool.
2. Return the task id and scheduled time.

## Demo Rule

The magic is "chat -> tool -> artifact". Always try to produce a real file, task, or visible action.
