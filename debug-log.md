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

