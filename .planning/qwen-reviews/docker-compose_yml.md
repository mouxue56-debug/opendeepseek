Config warnings:
- plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel plugin manifest declares wecom without channelConfigs metadata; add openclaw.plugin.json#channelConfigs so config schema and setup surfaces work before runtime loads
- plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel plugin manifest declares wecom without channelConfigs metadata; add openclaw.plugin.json#channelConfigs so config schema and setup surfaces work before runtime loads
│
◇  Config warnings ───────────────────────────────────────────────────────╮
│                                                                         │
│  - plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel     │
│    plugin manifest declares wecom without channelConfigs metadata; add  │
│    openclaw.plugin.json#channelConfigs so config schema and setup       │
│    surfaces work before runtime loads                                   │
│  - plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel     │
│    plugin manifest declares wecom without channelConfigs metadata; add  │
│    openclaw.plugin.json#channelConfigs so config schema and setup       │
│    surfaces work before runtime loads                                   │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────╯
model.run via local
provider: coding-plan-intl
model: qwen3.6-plus
outputs: 1
## 🔴 严重问题
### 1. 无认证 WebUI 默认监听 0.0.0.0 存在越权风险
- **位置**：`open-webui` -> `ports` (~行57)
- **问题**：Docker 默认端口映射至 `0.0.0.0`，结合默认 `WEBUI_AUTH=false`，任何局域网/公网 IP 均可直接访问并执行模型调用，存在严重未授权访问风险。
- **修改**：
  ```diff
  -       - "3000:8080"
  +       - "127.0.0.1:3000:8080"  # 家庭/单机模式仅限本地回环访问，公网必须走反向代理
  ```

### 2. SearXNG 挂载空目录导致容器启动崩溃
- **位置**：`searxng` -> `volumes` (~行95)
- **问题**：若宿主机不存在 `./searxng`，Docker 会创建 `root` 权限的空目录并覆盖容器 `/etc/searxng`，SearXNG 因缺失 `settings.yml` 直接 Crash，`full` profile 部署必败。
- **修改**：
  ```diff
  -       - ./searxng:/etc/searxng:rw
  +       # 方案A：首次启动移除该行使用内置默认配置，生成配置后恢复挂载
  +       - ./searxng/settings.yml:/etc/searxng/settings.yml:ro
  +       - ./searxng/limiter.toml:/etc/searxng/limiter.toml:ro
  ```

### 3. Hermes 健康检查强依赖容器内 Python3 解释器
- **位置**：`hermes` -> `healthcheck.test` (~行67)
- **问题**：若基础镜像为精简版（Alpine/Distroless），`python3` 不存在，健康检查永久失败，导致 `open-webui` 因 `condition: service_healthy` 永远挂起。
- **修改**：
  ```diff
  -       test: ["CMD-SHELL", "python3 -c \"import urllib.request; urllib.request.urlopen('http://localhost:8642/health')\" 2>/dev/null || exit 1"]
  +       test: ["CMD-SHELL", "curl -sf http://localhost:8642/health || wget -q --spider http://localhost:8642/health || exit 1"]
  ```

## 🟠 改进建议
### 1. SearXNG 端口无需暴露至宿主机
- **位置**：`searxng` -> `ports` (~行93)
- **问题**：WebUI 通过 Docker 内网 `http://searxng:8080` 调用，暴露 `8889` 增加非必要攻击面且违背最小暴露原则。
- **修改**：
  ```diff
  -       - "8889:8080"
  +       # 仅本地调试需访问控制台时开启，建议移除或改为 127.0.0.1:8889:8080
  ```

### 2. 核心密钥环境变量缺少强校验
- **位置**：`services` -> `environment` (多处 `${HERMES_API_KEY}` 等)
- **问题**：若未提供 `.env`，变量解析为空字符串，可能导致内部鉴权静默失败或密钥为空时意外放行，且缺乏明确报错指引。
- **修改**：
  ```diff
  -       - API_SERVER_KEY=${HERMES_API_KEY}
  -       - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}
  +       - API_SERVER_KEY=${HERMES_API_KEY:?Missing required: HERMES_API_KEY}
  +       - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY:?Missing required: WEBUI_SECRET_KEY}
  ```

### 3. Open WebUI 缺少对 SearXNG 的启动依赖声明
- **位置**：`open-webui` -> `depends_on` (~行82)
- **问题**：使用 `--profile full` 时 WebUI 可能先于 SearXNG 就绪，初始化阶段频繁请求 `http://searxng:8080` 会产生大量 Connection Refused 错误日志，干扰排障。
- **修改**：
  ```yaml
      depends_on:
        hermes:
          condition: service_healthy
        # 若开启 full profile，建议追加依赖（Compose 不支持条件 depends_on，可在 install.sh 中动态生成）
        searxng:
          condition: service_started
  ```

## 🟡 风格质量
### 1. `extra_hosts` 跨平台冗余配置
- **位置**：`open-webui` -> `extra_hosts` (~行85)
- **问题**：现代 Docker Desktop (Mac/Win) 及 Docker Engine 20.10+ 已内置 `host.docker.internal` 解析，硬编码可能引发旧版 DNS 冲突或冗余警告。
- **修改**：建议直接移除，依赖 Docker 默认行为。若需兼容极老环境，保留但添加 `# Requires Docker >= 18.03` 注释。

### 2. 镜像 Tag 版本策略未声明
- **位置**：顶部注释 & 各 `image` 字段
- **问题**：硬编码日期 Tag（如 `v2026.4.23`）与 `Generated: 2026-04-27` 存在偏移，且未说明 `install.sh` 是否自动拉取最新 Tag 或锁定 Digest，长期维护易产生“配置漂移”。
- **修改**：在文件头部补充 `# Tag Strategy: pinned-by-release.sh | 请勿手动修改 image tag`，或统一使用 `:latest` + `.env` 集中管理版本，提升一键脚本的幂等性。
