---
name: local-computer-agent
description: Work with the user's local files through /host, using Hermes terminal/file tools for real computer-adjacent automation
version: 1.0.0
metadata:
  hermes:
    tags: [opendeepseek, local-files, terminal, automation, desktop]
    related_skills: [wow-demo]
---

# Local Computer Agent

Use this skill whenever the user asks you to inspect, organize, create, edit, or automate local files on their computer.

## Mental Model

OpenDeepSeek mounts the user's chosen host directory at:

```text
/host
```

For the default setup, `/host` is the user's home directory. Common paths:

```text
/host/Desktop
/host/Documents
/host/Downloads
/host/OpenDeepSeek-Outputs
```

Do not say you cannot access local files until you have actually checked `/host`.

## Workflow

1. Start by checking the workspace:
   ```bash
   pwd
   ls -la /host | sed -n '1,80p'
   ```

2. For user-facing outputs, create:
   ```bash
   mkdir -p /host/OpenDeepSeek-Outputs
   ```

3. When inspecting private folders, summarize categories first. Avoid dumping large file lists unless the user explicitly asks.

4. For destructive actions such as deleting, moving, overwriting, or bulk renaming files, first prepare a plan and ask the user to confirm. Prefer writing a proposed plan to `/host/OpenDeepSeek-Outputs/`.

5. For creation tasks, actually create the artifact under `/host/OpenDeepSeek-Outputs/` and tell the user the exact `/host/...` path.

## High-Impact Demo Commands

Use these patterns for impressive demos:

- Desktop audit:
  ```bash
  find /host/Desktop -maxdepth 1 -mindepth 1 -print
  ```

- Create a polished HTML page:
  ```bash
  mkdir -p /host/OpenDeepSeek-Outputs/site
  ```

- Create a report:
  ```bash
  mkdir -p /host/OpenDeepSeek-Outputs/reports
  ```

- Create a slide outline:
  ```bash
  mkdir -p /host/OpenDeepSeek-Outputs/decks
  ```

## Response Style

Be concrete. Say what you inspected, what you created, and where it is. Do not hide behind generic chat answers.
