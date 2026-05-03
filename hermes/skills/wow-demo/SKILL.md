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
4. Verify the file with `test -s` or `wc -c`.
5. Tell the user both the `/host/...` path and the local computer path.

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

## Demo 6: Resume to Pitch Deck

User prompt:

```text
请读取 /host/Desktop/简历.pdf，把它改成 5 页中文自我介绍 PPT 大纲，并保存到 /host/OpenDeepSeek-Outputs/resume-deck.md。先确认文件是否存在，不存在就告诉我应该把文件放到哪里。
```

Expected behavior:

1. Check whether the file exists before claiming access.
2. If present, extract only the needed public career facts.
3. Write a structured Markdown deck outline.
4. Verify the output file exists and return both paths.

## Demo 7: Trip Planner With Reminders

User prompt:

```text
我下周去京都，请做一份 5 天中文旅行计划，保存成 /host/OpenDeepSeek-Outputs/kyoto-plan.md，并创建出发前一天晚上 8 点的提醒：检查护照和充电器。
```

Expected behavior:

1. Generate a real plan file.
2. Create a real cron reminder.
3. Return the file paths and reminder id.

## Demo 8: Error Doctor

User prompt:

```text
我会粘贴一段报错。请分析最可能原因、给 3 个修复方案，并把结果保存到 /host/OpenDeepSeek-Outputs/error-diagnosis.md。
```

Expected behavior:

1. Diagnose from the supplied error text.
2. Use web/browser tools only if available and needed.
3. Save the report and verify it.

## Demo 9: Knowledge From Voice Notes

User prompt:

```text
我会粘贴一段凌乱语音转录。请整理成「结论、证据、行动项、可拍摄镜头」四段，保存到 /host/OpenDeepSeek-Outputs/voice-note-brief.md。
```

Expected behavior:

1. Keep the user's emotion and personal voice.
2. Convert messy text into a structured artifact.
3. Save and verify the Markdown file.

## Demo 10: Safe Downloads Cleanup

User prompt:

```text
请查看 /host/Downloads 最近 30 天文件，只按类型统计并给整理建议，不移动、不删除。把报告写到 /host/OpenDeepSeek-Outputs/downloads-cleanup-plan.md。
```

Expected behavior:

1. Inspect metadata and names only.
2. Never move/delete without explicit confirmation.
3. Save a clear Chinese cleanup plan and verify it.

## Demo 11: Presentation → Landing Page Pivot

User is dissatisfied with or wants a different format for an existing generated webpage.

Common user request patterns:
- "把这个也做成网站形式来展现" — change from slide-based fullscreen to scrollable landing page
- "做成像官网那样" — make it look like a proper product site
- "不要翻页，直接滚动" — no slide navigation, pure scroll

Expected behavior when the user already has a slide-based (fullscreen page-by-page) index.html:

1. **Recognize the format gap**: Slide-based = `position:absolute;inset:0` with JS arrow key navigation. Landing page = scrollable sections with no slide JS. These are fundamentally different layouts.

2. **Complete rewrite approach** (don't try to patch the slide layout — it's fundamentally incompatible):
   - Remove all `.slide` + `.active` JS navigation code (keyboard/touch/progress bar)
   - Replace with `<section id="...">` elements (one per slide)
   - Replace slide-specific CSS (`.slide`, `.box`, `overflow:hidden`, `aspect-ratio`) with section-based layout
   - Add Intersection Observer for scroll-triggered fade-up animations
   - Keep all card content, evidence images, SVG flywheels exactly as-is

3. **Structural mapping** (slide → section):
   - S1 (fullscreen title) → `<section id="hero">` with centered hero layout
   - S2-S6 (content slides) → `<section id="comparison|pricing|flywheel|stack|evidence">` with `.container` + section-label/title/sub
   - S7 (closing) → `<section id="closing">` + `<footer>` element

4. **Key differences to implement**:
   - Remove `overflow:hidden` on body
   - Add `scroll-behavior:smooth` on html
   - Each section gets `min-height:100vh` instead of `position:absolute`
   - Add `.section-sep` dividers between sections (gradient line)
   - Replace slide `.active` animations with `.fade-up.visible` + Intersection Observer
   - Add scroll-down hint arrow at bottom of hero

5. **Evidence images**: Keep relative path `assets/` references exactly as before — no changes needed.

6. **Verify**: Check the assets directory still has the images, grep for `src="assets/` in the new HTML to confirm references are preserved.

## Demo Rule

The magic is "chat -> tool -> artifact". Always try to produce a real file, task, or visible action.

For large webpages, PPTs, or HTML artifacts:

1. Prefer generating via a small script or writing in chunks.
2. Avoid a single massive tool call argument.
3. Verify the final artifact with `test -s`, `wc -c`, or an equivalent file check.
4. Return `/host/...`, the local computer path, and a `file://` URL when possible.

### Key Learns

- When user says "把这个也做成网站形式" they mean **scrolling landing page**, not slide deck. These are opposite layouts.
- Never patch a slide-based layout into a landing page — do a complete rewrite.
- Slide content (text, images, SVGs) can be reused verbatim; only the container structure changes.
- Evidence images should stay in `assets/` with relative paths.
