# OpenDeepSeek Debug Log

## Round 1 - 静态校验 docker-compose.yml (status: PASS with fixes)

### 发现
- `searxng/` 目录不存在，但 docker-compose.yml 挂载 `./searxng:/etc/searxng:rw`，--profile full 时会出错
- `DEFAULT_MODEL` 在 docker-compose.yml 硬编码 `deepseek/deepseek-v4-flash`，未使用 `${DEFAULT_MODEL}` 变量
- README.md 手动安装章节写的端口是 `:8080`，应为 `:3000`
- docs/README.md 引用了不存在的 `docs/TAILSCALE.md`，以及端口写错为 `:8080`
- docker compose config 语法校验通过（warnings 只是变量未设置，正常）
- 镜像 tag 均存在于注册中心（hermes-agent:v2026.4.23 ✅，open-webui 需鉴权但已知存在）
- .env.example 存在 ✅
- 端口无冲突 ✅

### 修复
- 创建 `searxng/` 目录，原因：docker-compose.yml bind-mount 该目录，必须存在
- 改 docker-compose.yml `DEFAULT_MODEL=deepseek/deepseek-v4-flash` → `DEFAULT_MODEL=${DEFAULT_MODEL:-deepseek/deepseek-v4-flash}`，原因：让 .env 中的 DEFAULT_MODEL 生效
- 改 README.md 端口 `8080` → `3000`，原因：实际绑定端口是 3000
- 改 docs/README.md 端口 `8080` → `3000`，修复死链 TAILSCALE.md → CHINA-NETWORK.md

### 验证
- `docker compose config` 无 ERROR
- `python3 -c "import yaml; yaml.safe_load(...)"` 输出 YAML valid
- `curl docker hub API` 确认 nousresearch/hermes-agent:v2026.4.23 存在

### 下一轮关注
- setup.sh 语法检查，特别是 macOS 兼容性

## Round 2 - 静态校验 setup.sh (status: PASS with fix)

### 发现
- `bash -n setup.sh` 语法正确
- shellcheck 未安装，跳过
- macOS bash 3.2 兼容性：`seq`/`openssl`/`base64`/`read -rsp` 均兼容
- SKIP_CONFIG 分支读取 .env 时，`grep | cut` 管道：grep 返回空时 cut 还是 exit 0，导致 `|| echo "fallback"` 永不触发；若 .env 中 value 有 trailing space，`[[ "true  " == "true" ]]` 也会误判
- TOTAL=6 与实际 progress 调用数匹配（SKIP_CONFIG 分支少一次 progress 导致显示跳号，但不影响功能）

### 修复
- 改 setup.sh SKIP_CONFIG 分支 grep/cut，加 `tr -d '[:space:]'` 去除尾随空格，改用 `${var:-fallback}` 替代 `|| echo` 确保 fallback 生效

### 验证
- `bash -n setup.sh` 输出 syntax OK

### 下一轮关注
- docs/ 文档完整性和内部链接

## Round 3 - 文档完整性 (status: PASS with fixes)

### 发现
- docs/README.md 中链接用 `docs/INSTALL.md` 形式，但该文件本身在 docs/ 目录，应为 `INSTALL.md`
- docs/FAQ.md 中所有内部文档链接均用 `docs/IM-BRIDGE.md` 形式，会解析为 `docs/docs/IM-BRIDGE.md`（不存在）
- docs/FAQ.md 中 IM-BRIDGE.md 的锚链接 `#钉钉` 不匹配实际标题生成的 anchor `#1-钉钉机器人`
- 所有 docs/ 文件本身均存在（INSTALL.md, FAQ.md, IM-BRIDGE.md, CHINA-NETWORK.md, README.md）
- README.md（根目录）中引用 docs/INSTALL.md 等均正确（相对于项目根）

### 修复
- 修 docs/README.md 3 个链接去掉 `docs/` 前缀
- 修 docs/FAQ.md 5 个链接去掉 `docs/` 前缀
- 修 docs/FAQ.md IM-BRIDGE.md 锚链接为正确的 GFM anchor 格式

### 验证
- 所有引用文件均存在于对应相对路径

### 下一轮关注
- setup.sh 干跑测试，验证 .env 生成正确

## Round 4 - setup.sh 干跑测试 (status: PASS)

### 发现
- `bash -n setup.sh` 语法正确
- 使用 mock docker（TMPBIN stub）绕过真实 docker 调用
- 6 个 Phase 全部通过，.env 正确生成
- 所有变量正确写入：DEEPSEEK_API_KEY / DEFAULT_MODEL / HERMES_API_KEY / WEBUI_SECRET_KEY / ENABLE_CHINA_MODE
- Health check loop 如期 warn（mock docker 无真实容器），不影响脚本整体
- 无新 bug 发现

### 修复
- 无新修复

### 验证
- `printf "sk-test-...\n1\nY\nN\n" | PATH=<mock>:$PATH bash setup.sh` 完整跑通
- .env 包含所有 5 个必需变量 ✅

### 下一轮关注
- 真 docker compose up -d 启动核心服务

## Round 5 - 真 docker compose up 启动核心服务 (status: PASS with fix)

### 发现
- hermes 容器健康检查用 `CMD curl`，但 nousresearch/hermes-agent:v2026.4.23 镜像内**没有** curl
- 健康检查日志：`exec: "curl": executable file not found in $PATH`
- 由于 open-webui depends_on hermes `service_healthy`，hermes 始终 unhealthy → open-webui 无法启动
- 注：`command: gateway run` 已在此前未提交 diff 中修复（确保 hermes 以 API gateway 模式启动）

### 修复
- docker-compose.yml healthcheck 从 `CMD curl -f ...` 改为 `CMD-SHELL python3 -c "import urllib.request; urllib.request.urlopen(...)"` 原因：hermes 镜像无 curl，但有 python3（aiohttp 3.13.5 基础镜像）
- 同时提交 `command: gateway run` 修复

### 验证
- `docker compose up -d` 成功，hermes 状态 `healthy`，open-webui 状态 `healthy`
- `curl http://localhost:8642/health` → `{"status": "ok", "platform": "hermes-agent"}`
- `curl http://localhost:3000` → 200 HTML
- `docker compose ps` 两服务均 Up

### Commit
d8039e2 — debug round 5: add 'command: gateway run' to hermes service in docker-compose.yml
（下一 commit 含 healthcheck 修复）

