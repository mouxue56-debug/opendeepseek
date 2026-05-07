# OpenDeepSeek Goal Status

Last updated: 2026-05-07

## 2026-05-07 - CN Installer P0 Hardening

Status: done

Trigger:

- User ran `bash -c "$(curl -fsSL https://gitee.com/luoxueai/opendeepseek/raw/main/install-cn.sh)"` and saw no visible progress/output.

Root causes:

- Command substitution downloads the whole script before Bash starts; with `curl -s`, Gitee raw delays look like "nothing happened".
- `docker-compose.cn.yml` defaulted to future ACR image names that are not publicly pullable yet.
- CN network diagnostics could spend too long on GitCode Git deep checks.

Changed files:

- `install-cn.sh`
- `.env.example.cn`
- `docker-compose.cn.yml`
- `scripts/check-network-cn.sh`
- `scripts/creator-demo.sh`
- `README.md`
- `docs/zh-CN/00-我应该下载哪个版本.md`
- `docs/zh-CN/04-国内网络问题.md`
- `docs/OPENDEEPSEEK-CN-ROADMAP.md`

Validation:

- `bash -n install-cn.sh scripts/check-network-cn.sh`: PASS
- `docker compose -f docker-compose.cn.yml config -q`: PASS
- `docker manifest inspect openwebui/open-webui:0.9.2`: PASS
- `docker manifest inspect nousresearch/hermes-agent:v2026.4.23`: PASS
- `docker manifest inspect searxng/searxng:2026.4.28-ed5955a5c`: PASS
- Local install simulation with `OPDS_SKIP_START=true DEEPSEEK_API_KEY=sk-test-local OPDS_CN_NET_TIMEOUT=3 bash install-cn.sh`: PASS
- Current Gitee raw fetch with visible `curl -fL --connect-timeout 10 --max-time 30 ... -o /tmp/opds-gitee-before-push.sh`: PASS
- `scripts/creator-demo.sh` Gitee raw check was hardened to tolerate Gitee transient SSL/raw delays and to require the new `OPDS_SKIP_START` installer marker.

Decisions:

- README and CN docs now recommend visible download to `/tmp/opendeepseek-install-cn.sh`, not `bash -c "$(curl -fsSL ...)"`.
- CN compose defaults to public working images plus local Bridge build. Future domestic registry images can override `HERMES_IMAGE`, `BRIDGE_IMAGE`, `OPENWEBUI_IMAGE`, and `SEARXNG_IMAGE`.
- `install-cn.sh` supports `DEEPSEEK_API_KEY=...` non-interactive mode and `OPDS_SKIP_START=true` validation mode.
- GitCode Git deep probe is opt-in via `OPDS_CN_CHECK_GITCODE=true`; raw URL probe remains part of diagnostics.

Remaining risks:

- Full China Ready still requires publishing domestic ACR/CCR images and OSS/COS offline bundles.
- Local full CN startup was not run in this pass because existing OpenDeepSeek containers use the same container names.

## 2026-05-06 - Creator Release Provider And Doctor Pass

Status: done

Changed files:

- `AGENTS.md`
- `README.md`
- `.env.example`
- `.env.example.cn`
- `config/providers.example.json`
- `docker-compose.yml`
- `docker-compose.cn.yml`
- `bridge/hermes_image_bridge.py`
- `onboarding/index.html`
- `onboarding/server.py`
- `onboarding/static/style.css`
- `setup.sh`
- `scripts/doctor.py`
- `scripts/test-provider-config.py`
- `scripts/debug-rounds.sh`
- `scripts/verify_config.py`
- `scripts/goal-check.sh`
- `scripts/release-gate.sh`
- `docs/CONFIG-PROVIDERS.md`
- `docs/PERFORMANCE-TUNING.md`
- `docs/GOALS/CREATOR-RELEASE.md`
- `docs/README.md`

Validation:

- `python3 -m py_compile bridge/hermes_image_bridge.py onboarding/server.py scripts/verify_config.py scripts/doctor.py scripts/test-provider-config.py`: PASS
- `bash -n setup.sh install.sh install-cn.sh scripts/check-network-cn.sh scripts/goal-check.sh scripts/release-gate.sh scripts/debug-rounds.sh`: PASS
- `python3 -m json.tool config/providers.example.json`: PASS
- `python3 scripts/test-provider-config.py`: PASS
- `python3 scripts/benchmark_routing.py`: PASS - 56/56, F1=1.00
- `docker compose config -q`: PASS
- `docker compose -f docker-compose.cn.yml config -q`: PASS
- `./setup.sh verify`: PASS - 0 errors, 4 warnings because Docker/OpenDeepSeek runtime is intentionally stopped
- `./setup.sh doctor`: PASS - 0 errors, warnings only for stopped services/Docker daemon
- `./setup.sh report`: PASS - generated a redacted zip with 8 files; test artifact was removed after inspection
- `scripts/release-gate.sh`: PASS - 27 passed, 0 failed, 0 warnings, 1 skipped
- `scripts/goal-check.sh`: PASS - 25 passed, 0 failed, 2 skipped
- `scripts/debug-rounds.sh 10`: PASS - 10/10 rounds
- `./setup.sh fix`: PASS - non-destructively added Provider variables and created input/output/memory directories

Decisions:

- Creator Release is now written as the near-term product scope: do not fork Open WebUI, do not fork Hermes, keep OpenDeepSeek as product shell and stable glue.
- Open WebUI remains connected only to Smart Bridge.
- Default Provider remains DeepSeek V4 Flash.
- Advanced Provider is `custom` OpenAI-compatible API, covering OpenRouter, local Ollama/LM Studio/vLLM, domestic compatible platforms, LiteLLM, and self-hosted gateways without hardcoding every vendor in the main UX.
- Bridge lightweight path now uses `OPDS_LLM_PROVIDER`, `OPDS_LLM_BASE_URL`, `OPDS_LLM_API_KEY`, and `OPDS_LLM_MODEL`; Hermes task path is still preserved.
- Portal now shows DeepSeek by default and hides custom API fields in an advanced section.
- Resource defaults were lowered moderately for local comfort, but `HERMES_AGENT_MAX_TOKENS=32768` was preserved.
- `setup.sh doctor/report/fix` are read-only or non-destructive; no volume deletion, no Docker startup, no public exposure mutation.

Remaining risks:

- Full runtime smoke-test was not run because Docker/OrbStack daemon is currently stopped.
- Some custom providers may not support Tool Calls; docs warn that ordinary chat may work while Hermes Agent tasks may fail.
- Open WebUI PersistentConfig can keep older settings after first launch; users may still need Admin UI reset/migration tooling.

Next recommended goal:

```text
/goal 启动 Docker 后执行 full runtime validation：docker compose up -d，scripts/release-gate.sh --full，真实测试 Portal 自定义 Provider 页面、Open WebUI 模型列表、普通问答快路径、Hermes 文件写入、图片/OCR 和产物卡片。不 push、不 merge、不 tag。
```

## Current Baseline

Known working core chain:

- ordinary chat routes to DeepSeek V4 Flash lightweight path
- real tasks route to Hermes Agent
- `/host` file writes have been verified
- image/OCR bridge has been verified
- realtime progress stream has been verified
- OpenWebUI native tool calls are preserved
- `scripts/smoke-test.sh` previously passed 17/17
- Qwen3.6 five-round E2E debug previously passed 5/5

Current local runtime note:

- The local OpenDeepSeek Docker stack was intentionally stopped to save memory.
- Runtime smoke tests may need `docker compose up -d` before execution.

## 2026-05-06 - Goal Workbench Created

Status: done

Changed files:

- `AGENTS.md`
- `docs/GOALS/OPENDEEPSEEK-CN.md`
- `docs/GOALS/IMPLEMENT.md`
- `docs/GOALS/STATUS.md`
- `scripts/goal-check.sh`

Validation:

- `bash -n scripts/goal-check.sh`: PASS
- `scripts/goal-check.sh`: PASS - 15 passed, 0 failed, 2 skipped
- `python3 scripts/benchmark_routing.py`: PASS - 50/50, F1=1.00, via `scripts/goal-check.sh`
- `./setup.sh verify`: PASS - 0 errors, 4 warnings because the local Docker stack is intentionally stopped
- `bash scripts/smoke-test.sh`: SKIPPED - full runtime smoke-test disabled by default; run `OPDS_GOAL_FULL=true scripts/goal-check.sh` after `docker compose up -d`
- `shellcheck`: SKIPPED - not installed locally

Decisions:

- Use M0-M6 milestones for China-ready productization.
- Keep `/goal` work milestone-scoped.
- Do not modify core business code during workbench creation.
- Make M0 Release Gate the next recommended milestone before M1 China installer work.

Risks:

- The current docs include uncommitted planning changes; review diff before committing.
- Runtime validation requires the Docker stack to be running.
- Full smoke-test has not been re-run in this workbench step because the user intentionally stopped the local stack to save memory.

Next recommended goal:

```text
/goal 实现 M0：OpenDeepSeek 发布闸门检查。只新增 release gate 脚本和发布检查文档，不改 Bridge、Docker Compose、onboarding 或 setup.sh 核心逻辑。完成后运行 bash -n、scripts/goal-check.sh，并更新 docs/GOALS/STATUS.md。
```

## 2026-05-06 - M0 Release Gate

Status: done

Changed files:

- `scripts/release-gate.sh`
- `docs/RELEASE-CHECKLIST.md`
- `README.md`
- `docs/README.md`
- `scripts/goal-check.sh`
- `docs/GOALS/STATUS.md`

Validation:

- `bash -n scripts/release-gate.sh scripts/goal-check.sh`: PASS
- `scripts/release-gate.sh`: PASS - 26 passed, 0 failed, 0 warnings, 1 skipped
- `scripts/goal-check.sh`: PASS - 16 passed, 0 failed, 2 skipped
- `python3 scripts/benchmark_routing.py`: PASS - 50/50, F1=1.00, via release/goal checks
- `./setup.sh verify`: PASS - 0 errors, 4 warnings because Docker/OpenDeepSeek runtime is intentionally stopped after reboot
- `docker compose config`: PASS
- `bash scripts/smoke-test.sh`: SKIPPED - full runtime smoke-test intentionally not run while Docker stack is stopped; run `scripts/release-gate.sh --full` before actual release
- `shellcheck`: SKIPPED - not installed locally

Decisions:

- Release gate has a default lightweight mode that does not start the local stack.
- Full release validation remains available through `scripts/release-gate.sh --full` or `OPDS_RELEASE_FULL=true`.
- M0 did not modify Bridge, Docker Compose, onboarding, or setup core logic.

Risks:

- A true release still needs full smoke-test after starting Docker.
- Current work is not committed yet.

Next recommended goal:

```text
/goal 实现 M1：中国版安装与国内网络适配。范围只包括 install-cn.sh、install-cn.ps1、docker-compose.cn.yml、.env.example.cn、scripts/check-network-cn.sh、docs/zh-CN/04-国内网络问题.md、docs/zh-CN/05-离线安装.md、README 中国用户安装入口。不要做 Portal、Artifact、Memory 或镜像发布。
```

## 2026-05-06 - M1 China Installer And Network Adaptation

Status: done

Changed files:

- `install-cn.sh`
- `install-cn.ps1`
- `docker-compose.cn.yml`
- `.env.example.cn`
- `scripts/check-network-cn.sh`
- `docs/zh-CN/04-国内网络问题.md`
- `docs/zh-CN/05-离线安装.md`
- `README.md`
- `docs/README.md`
- `scripts/goal-check.sh`
- `docs/GOALS/STATUS.md`

Validation:

- `bash -n install-cn.sh scripts/check-network-cn.sh scripts/release-gate.sh scripts/goal-check.sh`: PASS
- `docker compose -f docker-compose.cn.yml config`: PASS
- `./setup.sh verify`: PASS - 0 errors, 4 warnings because Docker/OpenDeepSeek runtime is intentionally stopped after reboot
- `python3 scripts/benchmark_routing.py`: PASS - 50/50, F1=1.00
- `scripts/release-gate.sh`: PASS - 26 passed, 0 failed, 0 warnings, 1 skipped
- `scripts/goal-check.sh`: PASS - 19 passed, 0 failed, 2 skipped
- `install-cn.ps1` parse: SKIPPED - `pwsh` is not installed locally
- `scripts/check-network-cn.sh`: PASS as diagnostic command - 5 reachable, 7 warnings, 0 failures in the current network; warnings are expected because public Gitee/OSS/COS release assets are not published yet and local services are stopped
- `bash scripts/smoke-test.sh`: SKIPPED - runtime stack intentionally stopped; run full gate after `docker compose up -d`

Decisions:

- `docker-compose.cn.yml` is standalone and uses domestic registry variables.
- CN compose exposes only Open WebUI by default; Hermes, Bridge, and SearXNG stay internal.
- `install-cn.sh` prefers Gitee/GitCode/GitHub fallback through configurable repository URLs and supports offline image loading with `OPDS_CN_OFFLINE`.
- `.env.example.cn` narrows Agent file access to `~/OpenDeepSeek-Agent` by default.
- M1 does not claim China Ready is complete; docs explicitly say Gitee/GitCode mirrors, ACR images, OSS/COS bundles, and checksums still need publishing.

Risks:

- Default CN image tags are release placeholders until M2 publishes or documents image sync.
- `install-cn.ps1` has not been parsed by PowerShell on this machine because `pwsh` is unavailable.
- Full smoke-test was not re-run because the Docker stack is intentionally stopped.

Next recommended goal:

```text
/goal 实现 M2：国内镜像与离线包发布骨架。范围只包括 release-cn.json、scripts/sync-images-cn.sh、scripts/build-offline-bundle.sh、scripts/checksums.sh、docs/zh-CN/00-我应该下载哪个版本.md、docs/zh-CN/离线包发布流程.md。不要真实推送镜像，不上传 OSS/COS，不写云账号密钥。
```

## 2026-05-06 - M2 Domestic Images And Offline Bundles

Status: done

Changed files:

- `release-cn.json`
- `scripts/sync-images-cn.sh`
- `scripts/build-offline-bundle.sh`
- `scripts/checksums.sh`
- `docs/zh-CN/00-我应该下载哪个版本.md`
- `docs/zh-CN/离线包发布流程.md`
- `README.md`
- `docs/README.md`
- `docs/GOALS/STATUS.md`

Validation:

- `bash -n scripts/sync-images-cn.sh scripts/build-offline-bundle.sh scripts/checksums.sh`: PASS
- `python3 -m json.tool release-cn.json`: PASS
- `scripts/sync-images-cn.sh`: PASS in dry-run mode; printed target pull/tag/build commands and did not push
- `scripts/build-offline-bundle.sh --version 0.5.0-cn`: PASS; generated local ignored artifacts under `dist/cn/` and `checksums.txt`
- `scripts/checksums.sh -o /tmp/opds-m2-dist-checksums.txt dist/cn`: PASS
- `docker compose -f docker-compose.cn.yml config`: PASS
- `./setup.sh verify`: PASS - 0 errors, 4 warnings because Docker/OpenDeepSeek runtime is intentionally stopped after reboot
- `python3 scripts/benchmark_routing.py`: PASS - 50/50, F1=1.00
- `scripts/release-gate.sh`: PASS - 26 passed, 0 failed, 0 warnings, 1 skipped
- `scripts/goal-check.sh`: PASS - 22 passed, 0 failed, 2 skipped

Decisions:

- Domestic image sync defaults to dry-run. Real push requires `--push` plus `OPDS_CONFIRM_PUSH=I_UNDERSTAND`.
- `hermes-bridge` is built from the local `bridge/` directory; other images are pulled from upstream and retagged.
- Offline bundle building does not require Docker unless `--with-images` is requested.
- Release filenames use the full CN version suffix, for example `opendeepseek-cn-v0.5.0-cn-macos-arm64.zip`.
- `release-cn.json` remains a template until real OSS/COS URLs, commit, checksums, and image digests are filled during release.

Risks:

- No real domestic image push was performed.
- No OSS/COS upload was performed.
- Image tar bundle was not generated because Docker daemon is intentionally stopped and CN images are not present locally.
- Full smoke-test was not re-run because the Docker stack is intentionally stopped.

Next recommended goal:

```text
/goal 实现 M3：OpenDeepSeek 中文 Portal 与 onboarding 2.0。范围只包括 portal/onboarding 中文首页、服务状态卡片、API Key 设置入口、文件权限说明、诊断入口、产物入口占位、docs/zh-CN/06-填写DeepSeek-Key.md、docs/zh-CN/07-文件权限说明.md。不要深改 Open WebUI 品牌，不做 Artifact Manifest，不引入大型前端框架。
```

## 2026-05-06 - M3 Chinese Portal And Onboarding 2.0

Status: done

Changed files:

- `onboarding/index.html`
- `onboarding/static/style.css`
- `onboarding/server.py`
- `docs/zh-CN/06-填写DeepSeek-Key.md`
- `docs/zh-CN/07-文件权限说明.md`
- `README.md`
- `docs/README.md`
- `docs/GOALS/STATUS.md`

Validation:

- `python3 -m py_compile onboarding/server.py`: PASS
- `OPDS_NO_OPEN=1 python3 onboarding/server.py`: PASS - started on `127.0.0.1:3001` without opening browser
- `curl -fsS http://localhost:3001/`: PASS
- `curl -fsS http://localhost:3001/static/style.css`: PASS
- `curl -fsS http://localhost:3001/api/diagnostics`: PASS - returned local env, Docker, Compose, Open WebUI, Hermes, and SearXNG status without exposing API key
- `scripts/release-gate.sh`: PASS - 26 passed, 0 failed, 0 warnings, 1 skipped
- `scripts/goal-check.sh`: PASS - 22 passed, 0 failed, 2 skipped

Decisions:

- Keep Portal inside existing onboarding app instead of modifying Open WebUI branding.
- Add four product modes on the entry page: auto, fast, agent, deepwork.
- Add read-only diagnostics endpoint `/api/diagnostics`; it does not start Docker and does not mutate files.
- Add `OPDS_NO_OPEN=1` for automated onboarding server tests.
- Add file permission explanation and artifact center placeholder, leaving real Artifact Manifest implementation to M4.

Risks:

- No browser screenshot was captured in this milestone.
- Full smoke-test was not re-run because Docker/OpenDeepSeek runtime remains intentionally stopped.
- Artifact center is still a placeholder; actual manifest and preview service remain M4.

Next recommended goal:

```text
/goal 实现 M4：Artifact Manifest 与本地产物预览服务第一版。定义 docs/ARTIFACT-MANIFEST.md，在 Bridge 或 control sidecar 中实现 manifest 写入/读取，新增只读 /artifacts/<task_id>/... 预览，Hermes 文件任务完成后追加中文产物卡片。必须只服务 OpenDeepSeek-Outputs，禁止目录穿越、隐藏文件、.env 和密钥。
```

## 2026-05-06 - M4 Artifact Manifest And Preview

Status: done

Changed files:

- `bridge/hermes_image_bridge.py`
- `docker-compose.yml`
- `docker-compose.cn.yml`
- `.env.example`
- `.env.example.cn`
- `onboarding/server.py`
- `scripts/test-artifact-manifest.py`
- `scripts/smoke-test.sh`
- `scripts/goal-check.sh`
- `docs/ARTIFACT-MANIFEST.md`
- `README.md`
- `docs/README.md`
- `docs/GOALS/STATUS.md`

Validation:

- `python3 -m py_compile bridge/hermes_image_bridge.py scripts/test-artifact-manifest.py onboarding/server.py`: PASS
- `python3 scripts/test-artifact-manifest.py`: PASS - creates a temp output file, writes manifest, skips `.env`, verifies local path and preview URL
- `python3 scripts/benchmark_routing.py`: PASS - 50/50, F1=1.00
- `./setup.sh verify`: PASS - 0 errors, 4 warnings because Docker/OpenDeepSeek runtime is intentionally stopped after reboot
- `docker compose config`: PASS
- `docker compose -f docker-compose.cn.yml config`: PASS
- `scripts/goal-check.sh`: PASS - 23 passed, 0 failed, 2 skipped
- `scripts/release-gate.sh`: PASS - 26 passed, 0 failed, 0 warnings, 1 skipped
- `bash scripts/smoke-test.sh`: SKIPPED - runtime stack intentionally stopped; smoke-test now includes Artifact Manifest check for the next full run

Decisions:

- Implement Artifact Manifest in Smart Bridge because Bridge sees final Hermes responses and can append product cards.
- Only artifacts under `/host/OpenDeepSeek-Outputs` are eligible.
- Hidden files, `.env`, SSH key names, token/password-like filenames, and paths outside the output root are skipped.
- Add local-only preview port `127.0.0.1:${OPDS_ARTIFACT_PORT:-8770}:8765`; it does not follow `BIND_HOST` and does not expose Bridge publicly.
- Add endpoints: `GET /artifacts`, `GET /artifacts/<task_id>`, `GET /artifacts/<task_id>/manifest.json`, and `GET /artifacts/<task_id>/<relative-path>`.

Risks:

- First version is response-driven; if Hermes creates a file but does not mention the `/host/OpenDeepSeek-Outputs/...` path, Bridge cannot infer it.
- Preview service has not been tested against a live Docker stack in this run because Docker daemon is intentionally stopped.
- The preview port exposes Bridge on localhost only; do not change it to `0.0.0.0`.

Next recommended goal:

```text
/goal 实现 M5：OpenDeepSeek 虚拟模型和长任务控制增强。Bridge /v1/models 暴露 opendeepseek-auto、opendeepseek-fast、opendeepseek-agent、opendeepseek-deepwork；路由支持 auto/fast/agent/deepwork；默认/pinned model 配置更新；增加最小 run_id/status/stop 抽象。保持普通问答快，不破坏 OpenWebUI 原生 tools。
```

## 2026-05-06 - M5 Virtual Models And Run Control

Status: done

Changed files:

- `bridge/hermes_image_bridge.py`
- `scripts/benchmark_routing.py`
- `docker-compose.yml`
- `.env.example`
- `onboarding/server.py`
- `hermes/SOUL.md`
- `README.md`
- `docs/INSTALL.md`
- `docs/GOALS/STATUS.md`

Validation:

- `python3 -m py_compile bridge/hermes_image_bridge.py scripts/benchmark_routing.py scripts/test-artifact-manifest.py onboarding/server.py`: PASS
- `python3 scripts/benchmark_routing.py`: PASS - 56/56, F1=1.00, including virtual model cases
- `python3 scripts/test-artifact-manifest.py`: PASS
- Lightweight Bridge endpoint test with temporary host root:
  - `GET /v1/models`: PASS - returned `opendeepseek-auto`, `opendeepseek-fast`, `opendeepseek-agent`, `opendeepseek-deepwork`, `hermes-agent`, `deepseek-v4-flash`
  - `GET /runs`: PASS
  - `GET /artifacts`: PASS
- `docker compose config`: PASS
- `docker compose -f docker-compose.cn.yml config`: PASS
- `./setup.sh verify`: PASS - 0 errors, 4 warnings because Docker/OpenDeepSeek runtime is intentionally stopped after reboot
- `scripts/goal-check.sh`: PASS - 23 passed, 0 failed, 2 skipped
- `scripts/release-gate.sh`: PASS - 26 passed, 0 failed, 0 warnings, 1 skipped

Decisions:

- Bridge now owns `/v1/models` and exposes product modes directly to Open WebUI.
- `opendeepseek-auto` preserves automatic routing.
- `opendeepseek-fast` forces lightweight DeepSeek path unless image attachments require Hermes/OCR.
- `opendeepseek-agent` forces Hermes.
- `opendeepseek-deepwork` forces Hermes with the existing high output budget.
- Open WebUI defaults now prefer `opendeepseek-auto` and pin the four product modes.
- Minimal run state endpoints exist: `GET /runs`, `GET /runs/<run_id>`, `POST /runs/<run_id>/stop`. First version records status/stop requests but does not kill an already-sent upstream request.
- `hermes-agent` remains listed as a compatibility model.

Risks:

- Run stop is a control-plane placeholder, not hard cancellation.
- Open WebUI may persist old default model settings in its database after first launch; users may need Admin UI reset or future migration tooling.
- Full runtime smoke-test was not run because Docker daemon remains intentionally stopped.

Next recommended goal:

```text
/goal 实现 M6：发布材料。更新 README、docs/zh-CN、演示脚本和 release checklist，明确 China Ready 哪些已完成、哪些需要云账号发布；准备公开发布前人工卡口，不 push、不 merge、不 tag、不上传镜像或 OSS/COS。
```

## 2026-05-06 - M6 Release Materials

Status: done

Changed files:

- `README.md`
- `docs/README.md`
- `docs/RELEASE-CHECKLIST.md`
- `docs/DEMO-SCRIPT-CN.md`
- `docs/zh-CN/README.md`
- `docs/zh-CN/screenshots/README.md`
- `docs/GOALS/STATUS.md`

Validation:

- `scripts/build-offline-bundle.sh --version 0.5.0-cn`: PASS - regenerated local ignored bundle and checksum under `dist/cn/`
- `python3 -m py_compile bridge/hermes_image_bridge.py onboarding/server.py scripts/benchmark_routing.py scripts/test-artifact-manifest.py`: PASS
- `python3 scripts/benchmark_routing.py`: PASS - 56/56, F1=1.00
- `python3 scripts/test-artifact-manifest.py`: PASS
- `./setup.sh verify`: PASS - 0 errors, 4 warnings because Docker/OpenDeepSeek runtime is intentionally stopped after reboot
- `scripts/goal-check.sh`: PASS - 23 passed, 0 failed, 2 skipped
- `scripts/release-gate.sh`: PASS - 26 passed, 0 failed, 0 warnings, 1 skipped

Decisions:

- README now states M0-M5 local productization is complete but cloud release actions still need maintainer approval.
- Chinese docs now have a dedicated index under `docs/zh-CN/README.md`.
- Demo script focuses on real product proof: Portal, modes, Key, fast chat, Hermes Agent file generation, artifact card, China install path.
- Screenshot placeholders are documented without committing fake screenshots.
- Release checklist now includes Artifact Manifest, product modes, offline bundle, screenshot placeholders, and explicit manual approval boundaries.

Remaining manual release gates:

- Start Docker / OrbStack and run `scripts/release-gate.sh --full`.
- Sync GitHub to Gitee/GitCode.
- Push domestic images after `docker login` and explicit approval.
- Upload offline bundles to OSS/COS/CDN.
- Fill real commit, URLs, checksums, and image digests in `release-cn.json`.
- Tag release, merge PR, or publish GitHub/Gitee release only after human approval.

Next recommended goal:

```text
/goal 执行最终本地收尾：检查 git diff、确认没有 .env/密钥/大文件入库，运行最终 goal-check/release-gate，生成一份 FINAL-HANDOVER.md。不要启动 Docker，不 push，不 merge，不 tag。
```

## 2026-05-06 - Creator Final Mile Overnight Run

Status: done

Changed files:

- `CONTRIBUTING.md`
- `README.md`
- `docs/INSTALL.md`
- `docs/PUBLIC-DEPLOYMENT.md`
- `docs/OPENDEEPSEEK-CN-ROADMAP.md`
- `docs/zh-CN/00-我应该下载哪个版本.md`
- `docs/zh-CN/04-国内网络问题.md`
- `docs/zh-CN/视频拍摄检查清单.md`
- `docs/zh-CN/新用户安装实测报告.md`
- `install-cn.sh`
- `install-cn.ps1`
- `onboarding/index.html`
- `release-cn.json`
- `scripts/check-network-cn.sh`
- `scripts/creator-demo.sh`
- `OpenDeepSeek.command`
- `setup.sh`
- `bridge/hermes_image_bridge.py`

What changed:

- Replaced remaining `opendeepseek/opendeepseek` placeholders with `mouxue56-debug/opendeepseek`.
- Added `scripts/creator-demo.sh`, a video-recording preflight that checks git sync, Gitee mirror, Docker stack, DeepSeek, Bridge fast route, Hermes Agent file writes, Cron skill, and Portal.
- Added a Chinese video shooting checklist.
- Improved `OpenDeepSeek.command` so macOS users can double-click to start, auto-wait Docker/OrbStack, run setup when `.env` is missing, and otherwise start the lightweight stack.
- Ran a fresh GitHub clone simulation in `/tmp` and documented timings in `docs/zh-CN/新用户安装实测报告.md`.
- Fixed startup staleness by rebuilding the local `hermes-bridge` image on `./setup.sh start` / `start-full` / first setup start, so users do not keep running old Bridge code after pulling fixes.
- Fixed Bridge run-state bookkeeping: `set_run_state(..., status=response.status_code)` no longer conflicts with the run lifecycle state argument.

Validation:

- `bash -n setup.sh install.sh install-cn.sh scripts/*.sh OpenDeepSeek.command`: PASS
- `docker compose config -q`: PASS
- `docker compose -f docker-compose.cn.yml config -q`: PASS
- `python3 -m py_compile bridge/hermes_image_bridge.py`: PASS
- `python3 scripts/benchmark_routing.py`: PASS - 56/56, F1=1.00
- `python3 scripts/test-provider-config.py`: PASS
- `python3 scripts/test-artifact-manifest.py`: PASS
- `./setup.sh verify`: PASS - 0 errors, 1 warning because SearXNG is intentionally stopped in lightweight mode
- `./scripts/goal-check.sh`: PASS - 26 passed, 0 failed, 2 skipped (`shellcheck` not installed; full smoke-test disabled in goal-check)
- `bash scripts/smoke-test.sh`: PASS - 18 passed, 0 failed
- `./scripts/release-gate.sh --full`: PASS - 28 passed, 0 failed, 0 warnings, 0 skipped
- Fresh install from GitHub in `/tmp`: PASS - clone 1s, lightweight start 17s, healthy wait 31s, Portal/Open WebUI/Bridge checks passed

Runtime state after validation:

- `opendeepseek-webui`: healthy on `127.0.0.1:3000`
- `opendeepseek-hermes-bridge`: healthy on `127.0.0.1:8770`
- `opendeepseek-hermes`: healthy on `127.0.0.1:8642`
- SearXNG is not running by default to keep memory lower; use `./setup.sh start-full` only when search is needed.

Remaining Gitee follow-up:

- User created `https://gitee.com/luoxueai/opendeepseek`; defaults now point to that repository. The demo preflight now checks both the project page and `raw/main/install-cn.sh` so an empty Gitee repo cannot pass as China-ready.

Backup:

- Original remote `origin/main` was backed up to `backup/origin-main-20260506-232300-300a606` before replacing GitHub main with the Creator Release branch.

Next morning:

```bash
cd /Users/lauralyu/projects/opendeepseek/.claude/worktrees/stoic-rhodes-f8b694
./setup.sh start
open http://localhost:3000
```

Before recording:

```bash
./scripts/creator-demo.sh
```

If it fails only on Gitee, verify the Gitee mirror has synced the latest GitHub `main`:

```text
https://gitee.com/luoxueai/opendeepseek
source: https://github.com/mouxue56-debug/opendeepseek
raw check: https://gitee.com/luoxueai/opendeepseek/raw/main/install-cn.sh
```

## 2026-05-07 - Full-Chain OpenClaw Review + Landing Hardening

Status: done - code hardening implemented and pushed to GitHub/Gitee; live end-to-end demo is blocked only by invalid DeepSeek API key in local `.env`

Sidecars:

- Qwen3.6, Kimi K2.6, and MiMo 2.5 Pro each performed a full-chain review of install, Gitee, startup, routing, Hermes, artifact, video preflight, and China-ready release. Codex retained final judgment and only implemented low-risk changes.

Changed files:

- `scripts/health-check.sh`
- `scripts/sync-gitee.sh`
- `scripts/creator-demo.sh`
- `scripts/provider-live-check.py`
- `setup.sh`
- `install-cn.sh`
- `scripts/check-network-cn.sh`
- `README.md`
- `docs/zh-CN/视频拍摄检查清单.md`
- `docs/zh-CN/新用户安装实测报告.md`
- `docs/zh-CN/04-国内网络问题.md`
- `docs/zh-CN/README.md`

What changed:

- Added a unified JSON health check for Open WebUI, Bridge, Hermes, and Artifact listing.
- Added a Gitee sync helper that pushes current HEAD with `GITEE_TOKEN` from the environment, verifies remote branch SHA, and verifies `raw/main/install-cn.sh`.
- `creator-demo.sh` now fails if tracked files are dirty, verifies Gitee raw installer, and prints a video-ready endpoint summary after all checks pass.
- `install-cn.sh` now reports line-level failure context and only treats a repo as reachable if `main` or `master` actually exists.
- `scripts/check-network-cn.sh` now avoids false-positive Git repo checks by requiring real `main` or `master` refs.
- Docs now reflect that Gitee raw is active while GitCode, domestic images, and offline bundles remain release follow-ups.
- Added `./setup.sh verify-live` / `scripts/provider-live-check.py` for real Provider API key, balance, Base URL, and model validation.

Validation so far:

- `bash -n install-cn.sh install-cn.ps1 setup.sh OpenDeepSeek.command scripts/*.sh`: PASS
- `python3 -m py_compile scripts/provider-live-check.py scripts/verify_config.py scripts/doctor.py bridge/hermes_image_bridge.py`: PASS
- `python3 scripts/benchmark_routing.py`: PASS - 56/56, F1=1.00
- `./scripts/health-check.sh`: PASS - `overall=ok`
- `./scripts/sync-gitee.sh --verify-only`: PASS - Gitee `main` matches local HEAD, raw installer content verified
- `./setup.sh verify`: PASS - 0 errors, 1 expected SearXNG warning
- `docker compose config -q`: PASS
- `docker compose -f docker-compose.cn.yml config -q`: PASS
- `./setup.sh verify-live`: FAIL as expected with current local `.env` - DeepSeek HTTP 401, configured API key is invalid
- `./scripts/creator-demo.sh`: FAIL at step 4 for the same DeepSeek HTTP 401; steps 1-3 pass (GitHub sync, Gitee project/raw, Docker stack)
- `./scripts/release-gate.sh`: PASS - 27 passed, 0 failed, 1 skipped
- `./scripts/goal-check.sh`: PASS - 28 passed, 0 failed, 2 skipped

Pushed:

- GitHub `main`: synced to local HEAD
- Gitee `main`: synced to local HEAD

Next:

- Replace the local DeepSeek key via Portal or `.env`, then run `./setup.sh verify-live`, `./scripts/creator-demo.sh`, and `./scripts/release-gate.sh --full`.

## 2026-05-07 - New DeepSeek Key Live Validation + E2E Benchmark

Status: done - local stack and public GitHub/Gitee code are launch-ready for the current lightweight OpenDeepSeek path.

What changed:

- Updated local `.env` only with a fresh DeepSeek V4 Flash API key. `.env` remains untracked and was not committed.
- Restarted the lightweight stack so Hermes and Smart Bridge read the new provider credentials.
- Hardened `scripts/creator-demo.sh` with retrying Gitee checks after one transient Gitee HTTP `000` failure.

Validation:

- `./setup.sh verify-live`: PASS - Provider returned content from `deepseek-v4-flash`
- `./scripts/health-check.sh`: PASS - `overall=ok`
- `./scripts/sync-gitee.sh --verify-only`: PASS - Gitee main matches local HEAD and raw installer content verified
- `./scripts/creator-demo.sh`: PASS - 8/8 checks passed, including Gitee raw, Docker stack, DeepSeek API, fast route, Hermes file write, Cron skill, and Portal
- `./scripts/release-gate.sh --full`: PASS - 28 passed, 0 failed, 0 warnings, 0 skipped
- `python3 scripts/agent-e2e-benchmark.py`: PASS - 10/10 conversations, 30 turns, 0 failed, average latency 10.9s, p95 65.4s

Benchmark artifacts:

- Report: `benchmark-results/agent-e2e-20260507-141032.json`
- Generated files under `/host/OpenDeepSeek-Outputs/benchmark`:
  - `session03.txt`
  - `site-demo/index.html`
  - `weekly-report.md`
  - `video-script.md`

## 2026-05-07 - 3-Round Multi-Model Debug: CN Lightweight Search + Diagnostics

Status: done - Qwen3.6, Kimi K2.6, and MiMo 2.5 Pro completed three full-chain debug rounds; Codex verified and landed the selected fixes.

Round summary:

- Round 1 found a real CN mismatch: `.env.example.cn` enabled realtime search while `docker-compose.cn.yml` kept SearXNG behind the `full` profile. The same round also found noisy warnings from unpublished GitCode/OSS/COS checks.
- Round 2 reviewed the first patch and caught a macOS Bash 3.2 compatibility bug in the initial boolean parser. Codex replaced Bash 4 lowercase expansion with portable `tr` parsing and validated shell env, `.env`, and inline-comment paths.
- Round 3 found no P0/P1 blockers; all three sidecars returned ship-ready/no-blocker guidance.

Changed files:

- `.env.example.cn`
- `docker-compose.cn.yml`
- `install-cn.sh`
- `scripts/enable-full-agent-access.sh`
- `scripts/check-network-cn.sh`
- `docs/zh-CN/04-国内网络问题.md`
- `docs/GOALS/STATUS.md`

What changed:

- CN installs now default to lightweight mode with `OPDS_REALTIME_SEARCH_ENABLED=false`, avoiding SearXNG memory overhead unless the user explicitly enables realtime search.
- If `OPDS_REALTIME_SEARCH_ENABLED=true` is set in the shell or `.env`, `install-cn.sh` automatically starts Docker Compose with `--profile full` so SearXNG actually runs.
- `install-cn.sh` now parses boolean `.env` values portably on macOS Bash 3.2, including quoted values and inline comments such as `OPDS_REALTIME_SEARCH_ENABLED=true # comment`.
- `install-cn.sh` no longer overwrites an existing custom `HERMES_HOST_DIR` / full-agent directory on rerun; it only expands placeholders and keeps the chosen host directory.
- `scripts/enable-full-agent-access.sh` now writes `OPDS_HOST_DISPLAY_PREFIX` together with `HERMES_HOST_DIR`, and restarts `hermes-bridge` as well as Hermes/Open WebUI so replies show the real local file path.
- `scripts/check-network-cn.sh` no longer warns by default for unpublished GitCode raw or OSS/COS release manifests; those probes are opt-in through `OPDS_CN_CHECK_GITCODE=true` and `OPDS_CN_CHECK_RELEASE_MANIFESTS=true`.
- CN docs now explain the lightweight default and how to enable search.

Validation:

- `bash -n install-cn.sh scripts/check-network-cn.sh`: PASS
- `docker compose -f docker-compose.cn.yml config -q`: PASS
- `docker compose -f docker-compose.cn.yml --profile full config -q`: PASS
- `OPDS_CN_NET_TIMEOUT=3 bash scripts/check-network-cn.sh`: PASS - 8 reachable, 0 warnings, 0 failures
- Fake Docker default install simulation: PASS - lightweight path, no `--profile full`
- Fake Docker `OPDS_REALTIME_SEARCH_ENABLED=true` simulation: PASS - full profile path includes `--profile full`
- Fake Docker `.env` inline-comment simulation: PASS - `OPDS_REALTIME_SEARCH_ENABLED=true # comment` triggers full profile
- Fake Docker custom `HERMES_HOST_DIR` rerun simulation: PASS - custom host/display prefix preserved
- `./scripts/enable-full-agent-access.sh "$HOME"`: PASS - local runtime remounted `/Users/lauralyu` and Bridge now reports `OPDS_HOST_DISPLAY_PREFIX=/Users/lauralyu`
- `./scripts/release-gate.sh --full`: PASS - 28 passed, 0 failed, 0 warnings, 0 skipped
  - `desktop-plan.md`

Pushed:

- GitHub `main`: synced to local HEAD
- Gitee `main`: synced to local HEAD

Remaining release follow-ups:

- GitCode mirror is still a follow-up.
- Domestic container images and OSS/COS offline bundles are still follow-ups before claiming full China Ready.
- Public/cloud deployment still requires `WEBUI_AUTH=true`, HTTPS/reverse proxy, and no unauthenticated public Hermes/Bridge exposure.
