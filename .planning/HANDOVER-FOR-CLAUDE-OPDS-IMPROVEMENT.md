# Handover for Claude: OpenDeepSeek 改进与性能收口

Last updated: 2026-05-06

## 0. Claude 接手命令

```bash
cd /Users/lauralyu/projects/opendeepseek/.claude/worktrees/stoic-rhodes-f8b694
cat .planning/HANDOVER-FOR-CLAUDE-OPDS-IMPROVEMENT.md
```

接手后先跑只读检查：

```bash
git status --short
git log --oneline -5
./setup.sh doctor
```

不要一上来启动 full profile。需要真实运行时，先开 Docker/OrbStack，再用：

```bash
./setup.sh start
```

只有需要联网搜索/SearXNG 时才用：

```bash
./setup.sh start-full
```

## 1. 项目定位，别跑偏

OpenDeepSeek 的方向已经收窄：

> OpenDeepSeek = Open WebUI + Hermes + DeepSeek/自定义 API 的一键整合产品壳。代码少动，体验多打磨。

不要 fork Open WebUI，不要 fork Hermes，不要重写 Agent runtime，不要自研完整聊天 UI。

本项目真正该做的是：

- 中文引导
- API/Provider 配置向导
- Smart Bridge 稳定胶水
- 一键诊断
- 国内安装
- 产物展示
- 演示任务库
- 性能/内存友好默认值

Open WebUI 永远只连 Smart Bridge；Bridge 决定普通问答走轻量 Provider 还是 Hermes Agent；Hermes 负责真实文件/工具/记忆/定时任务。

## 2. 最新重要 commit

当前 HEAD 应为：

```text
f52074e fix: make default startup lightweight
```

上一轮产品化 commit：

```text
f41f387 feat: add creator release provider setup
af85883 feat: productize OpenDeepSeek CN release path
```

其中 `f52074e` 是本 handover 最重要的性能修复。

## 3. 用户最近问题

用户反馈：

> 每次启动 OpenDeepSeek 项目电脑都会变得非常卡。

调查结果：

1. 当时 Docker/OrbStack daemon 没开，所以“当前此刻”不是 OpenDeepSeek 容器在吃资源。
2. 当时 CPU 最高的是：

```text
/opt/homebrew/opt/node/bin/node /opt/homebrew/lib/node_modules/openclaw/dist/index.js gateway --port 18790
```

这是 OpenClaw gateway，刚查时曾接近 100% CPU，后来降到很低。它不属于 OpenDeepSeek 容器，但会让用户误以为“项目卡”。

3. OpenDeepSeek 自身确实有一个默认启动策略问题：
   - 旧 `.env` 里有 `ENABLE_CHINA_MODE=true`
   - `setup.sh` simple mode 会把 `ENABLE_CHINA_MODE=true` 写进去
   - 启动阶段看到 true 就执行：

```bash
docker compose --profile full up -d
```

这会额外启动 SearXNG。

4. Open WebUI 还默认开启了较重功能：

```env
ENABLE_CODE_INTERPRETER=true
ENABLE_RAG_HYBRID_SEARCH=true
```

这些对小白第一次启动和低内存电脑都不友好。

## 4. 已做修复

### 4.1 默认启动改成轻量模式

文件：

- `setup.sh`
- `README.md`
- `docs/PERFORMANCE-TUNING.md`

新增命令：

```bash
./setup.sh start       # 轻量启动：OpenWebUI + Bridge + Hermes
./setup.sh start-full  # 完整启动：额外含 SearXNG
./setup.sh stop        # 停止容器，不删 volume
./setup.sh stats       # 查看 docker stats
```

`setup.sh` simple mode 现在默认：

```env
ENABLE_CHINA_MODE=false
ENABLE_RAG_WEB_SEARCH=false
ENABLE_CODE_INTERPRETER=false
ENABLE_RAG_HYBRID_SEARCH=false
```

### 4.2 Compose 资源默认下调

文件：

- `docker-compose.yml`
- `docker-compose.cn.yml`
- `.env.example`
- `.env.example.cn`

默认资源上限：

```env
HERMES_CPUS=1.5
HERMES_MEMORY_LIMIT=1280m
WEBUI_CPUS=1.0
WEBUI_MEMORY_LIMIT=1024m
BRIDGE_CPUS=0.5
BRIDGE_MEMORY_LIMIT=256m
SEARXNG_CPUS=0.5
SEARXNG_MEMORY_LIMIT=384m
```

注意：没有降低 `HERMES_AGENT_MAX_TOKENS=32768`。用户明确要求不要降低输出预算，因为网页/PPT/报告任务会被截断。

### 4.3 Doctor 增强

文件：

- `scripts/doctor.py`

现在 `./setup.sh doctor` 会提示：

- 当前 `.env` 是否还在 `ENABLE_CHINA_MODE=true`
- 是否开启了 `ENABLE_CODE_INTERPRETER`
- 是否开启了 `ENABLE_RAG_HYBRID_SEARCH`
- Docker daemon 是否运行
- 端口是否监听
- Provider 是否配置
- `/host` 输出目录是否可写

### 4.4 本机 `.env` 已被安全修复

已执行：

```bash
./setup.sh fix
```

它做了：

- 补齐 Provider 变量
- 切回轻量启动配置
- 创建 `OpenDeepSeek-Inputs` / `OpenDeepSeek-Outputs` / `OpenDeepSeek-Memory`

它没有做：

- 不删除 volume
- 不启动容器
- 不修改公网暴露设置

注意：`.env` 不入库，Claude 在新环境或用户机器上需要让用户跑：

```bash
./setup.sh fix
```

## 5. Provider 改进现状

上一轮 `f41f387` 已完成：

- 默认 DeepSeek
- 高级自定义 OpenAI-compatible API
- Portal 默认只显示 DeepSeek，高级折叠显示 custom
- Bridge 轻量路径读取：

```env
OPDS_LLM_PROVIDER
OPDS_LLM_BASE_URL
OPDS_LLM_API_KEY
OPDS_LLM_MODEL
```

文档：

- `docs/CONFIG-PROVIDERS.md`
- `config/providers.example.json`

支持范围：

- DeepSeek 官方 API
- OpenRouter
- 本地 Ollama / LM Studio / vLLM
- 国内 OpenAI-compatible 平台
- LiteLLM
- 自建网关

产品原则：

Open WebUI 不让小白手动配 Connections，仍然只连 Smart Bridge。

## 6. 验证结果

性能修复后已跑：

```bash
bash -n setup.sh scripts/doctor.py scripts/debug-rounds.sh scripts/release-gate.sh scripts/goal-check.sh
python3 -m py_compile scripts/doctor.py scripts/verify_config.py onboarding/server.py bridge/hermes_image_bridge.py
docker compose config -q
docker compose -f docker-compose.cn.yml config -q
./setup.sh verify
python3 scripts/benchmark_routing.py
python3 scripts/test-provider-config.py
python3 scripts/test-artifact-manifest.py
./setup.sh doctor
scripts/release-gate.sh
scripts/goal-check.sh
```

关键结果：

```text
benchmark_routing.py: 56/56, F1=1.00
release-gate.sh: 27 pass, 0 fail, 1 skipped
goal-check.sh: 25 pass, 0 fail, 2 skipped
setup.sh verify: 0 errors, 4 warnings
setup.sh doctor: 0 errors, warnings 来自 Docker/服务未启动
```

跳过/未做：

- 没跑 full runtime smoke-test，因为 Docker/OrbStack daemon 当时没运行。
- 没启动容器做真实 `docker stats`，避免在用户反馈“电脑卡”的现场继续加负载。

## 7. Claude 下一步优先级

### P0：真实轻量启动资源验证

等 Docker/OrbStack 开启后，跑：

```bash
./setup.sh start
sleep 20
./setup.sh stats
docker compose ps
./setup.sh doctor
```

要确认：

- `opendeepseek-searxng` 不应启动
- Open WebUI、Hermes、Bridge 三个核心服务启动
- CPU/内存符合预期
- `http://localhost:3000` 可打开
- `http://localhost:8770/health` 可访问

如果用户要搜索，再跑：

```bash
./setup.sh start-full
./setup.sh stats
```

对比 SearXNG 的额外占用。

### P1：Open WebUI PersistentConfig 检查

Open WebUI 某些配置首次启动后会进数据库。即使 `.env` 改了，旧 DB 里可能还保留：

- Code Interpreter 开启
- RAG hybrid/search 开启
- 默认模型不是 `opendeepseek-auto`

如果用户说“还是慢”，下一步查 Open WebUI Admin 设置，或做一个安全的配置迁移工具。注意不要删除聊天记录。

### P2：Portal 增加“轻量/完整”模式按钮

Portal 可以更直观：

```text
启动模式：
[轻量模式，推荐] OpenWebUI + Bridge + Hermes
[完整搜索模式] 额外启动 SearXNG，适合早报/联网调研
```

现在 CLI 已有 `start/start-full`，Portal 还没做模式切换。

### P3：Doctor 增加资源快照

建议给 `scripts/doctor.py` 增加：

- top CPU processes
- top memory processes
- Docker stats if daemon running
- OrbStack/Docker Desktop running state

这样下次用户说“卡”，doctor 报告能直接定位是容器、OpenClaw、Chrome、Claude、Codex 还是系统 Spotlight。

### P4：真实 10 轮 runtime smoke

Docker 启动后再跑：

```bash
scripts/release-gate.sh --full
```

并真实验证：

- 普通问答走 lightweight route
- `/agent` 写文件
- 图片/OCR
- 产物卡片
- Provider custom 表单
- `./setup.sh stop` 能释放资源

## 8. 绝对不要做

- 不要默认启动 `--profile full`
- 不要默认启用 SearXNG
- 不要默认打开 Code Interpreter
- 不要默认打开 RAG hybrid/search
- 不要降低 `HERMES_AGENT_MAX_TOKENS`
- 不要删除 Open WebUI volume
- 不要为了“修慢”把 Hermes Agent 关掉
- 不要把项目退化成普通聊天壳
- 不要把 `.env` 提交
- 不要 push/tag/release，除非用户明确批准

## 9. 给 Claude 的接手 Prompt

```text
读 /Users/lauralyu/projects/opendeepseek/.claude/worktrees/stoic-rhodes-f8b694/.planning/HANDOVER-FOR-CLAUDE-OPDS-IMPROVEMENT.md，
理解 OpenDeepSeek 当前定位、最新性能修复和 Creator Release 方向后继续推进。

当前重点不是重写 OpenWebUI/Hermes，而是继续打磨产品壳：
1. 验证轻量启动是否真的不再卡；
2. 检查 OpenWebUI PersistentConfig 是否保留重功能；
3. 在 Portal 增加轻量/完整搜索模式选择；
4. 增强 doctor/report 的资源诊断；
5. Docker 启动后跑 full runtime smoke-test。

不要默认启动 full profile，不要降低 Hermes 输出预算，不要删除用户 volume，不要提交 .env。
```

## 10. 一句话总结

这次真正修的是“默认启动太重”的产品问题：以前小白启动可能直接进 full/SearXNG，并且 OpenWebUI 重功能默认开；现在默认轻量启动，搜索和重功能按需开启。下一步 Claude 应该用真实 Docker 启动验证资源占用，并继续把这个体验做进 Portal 和 doctor。
