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


