# Open WebUI v0.9.x 小白零门槛配置调研

> 调研日期：2026-04-29  
> 适用版本：Open WebUI v0.9.x  
> 官方文档根：https://docs.openwebui.com/reference/env-configuration/

---

## 1. 关闭登录（single-user 模式）

### `WEBUI_AUTH=false` 能否真正跳过登录？

**可以，但有严格前提条件。**

官方文档 [https://docs.openwebui.com/reference/env-configuration/] 明确：`WEBUI_AUTH=False` 禁用整个认证层。但有两个硬性限制：

1. **必须是全新安装（zero existing users）**。若数据库已有用户，设置会被忽略并报错："You can't turn off authentication because there are existing users."（来源：[GitHub #9896](https://github.com/open-webui/open-webui/issues/9896)）
2. **一旦设置无法切换**。官方说明 cannot switch between single-user mode and multi-account mode after this change。

**已知 bug（v0.9.x）**：[Discussion #15285](https://github.com/open-webui/open-webui/discussions/15285) 记录了 `WEBUI_AUTH=False` 后前端仍尝试发送 `POST /api/v1/auths/signin`，导致 400 错误。根因是**浏览器残留 cookie**。解决方案：首次访问前清除浏览器站点数据（或使用无痕模式）。

### 还需要 `ENABLE_SIGNUP=false` 吗？

不需要额外加。官方安全文档 [https://docs.openwebui.com/getting-started/advanced-topics/hardening/] 说明：**"Signup is open only until the first user registers, who becomes the administrator. After that, signup is automatically disabled."** 即首个用户注册后自动关闭注册。`WEBUI_AUTH=False` 模式下根本没有注册流程，`ENABLE_SIGNUP` 无意义。

若你用了 `WEBUI_ADMIN_EMAIL`+`WEBUI_ADMIN_PASSWORD` 预建管理员账号（多用户模式），则 **建议加 `ENABLE_SIGNUP=false`** 防止他人注册。

### 单用户模式下的管理员权限

`WEBUI_AUTH=False` 下，**所有访问者自动具备完整 admin 权限**（无登录、无角色区分）。来源：[Discussion #10982](https://github.com/open-webui/open-webui/discussions/10982)："each person will be changing and overwriting the settings of the previous, and they'll all have admin rights."

对家庭单人部署：这是期望行为（直接进 Admin Panel 配置）。对多人共享：风险极高，任何人都能删除他人对话、修改全局设置。

### 安全风险评估

| 场景 | 风险等级 | 说明 |
|------|---------|------|
| 本地回环（localhost） | **极低** | 仅本机可访问，无网络暴露 |
| 局域网 / Tailscale | **低-中** | 同网段设备均可无密码操作；Tailscale 已有网络层隔离，风险可控 |
| 公网直接暴露 | **极高** | 任何人均可使用并操控，强烈不建议；官方文档明确"设计用于私有可信网络" |

官方建议公网部署必须加反向代理 + VPN/Zero-Trust。来源：[https://docs.openwebui.com/getting-started/advanced-topics/hardening/]

---

## 2. 默认模型预设

### 正确的 env var：`DEFAULT_MODELS`

官方文档 [https://docs.openwebui.com/reference/env-configuration/] 确认正确变量名为 **`DEFAULT_MODELS`**（不是 `WEBUI_DEFAULT_MODELS` 或 `ENABLE_DEFAULT_MODELS`，这两个不存在）。

- **类型**：`str`，默认为空
- **含义**：设置用户新建对话时的默认预选模型
- **标记**：`PersistentConfig`（首次启动写入数据库后，后续修改 env var 不会覆盖，除非设 `ENABLE_PERSISTENT_CONFIG=false`）

### 值的格式

使用**模型 ID**（即 API 返回的 model id），**逗号分隔**多个模型。示例来源：[Docker Docs Open WebUI Integration](https://docs.docker.com/ai/model-runner/openwebui-integration/)：

```
DEFAULT_MODELS=ai/llama3.2
DEFAULT_MODELS=ai/llama3.2,ai/qwen2.5-coder
```

对本项目，hermes 服务暴露的模型 ID 通过 `GET http://hermes:8642/v1/models` 获取，示例：

```
DEFAULT_MODELS=hermes-agent
```

附加变量 `DEFAULT_PINNED_MODELS`（同格式，逗号分隔）：在模型选择器中置顶显示，适合小白"无需滚动找模型"。

### 是否需要先在 Connections 配 OpenAI provider？

**不需要**。env var `OPENAI_API_BASE_URL` + `OPENAI_API_KEY` 已在当前 docker-compose 中配置，Open WebUI 启动时自动加载该 provider。`DEFAULT_MODELS` 只是在已有模型列表中选一个作为默认，不替代 provider 配置。

---

## 3. 默认启用功能

### 联网搜索（Web Search）

官方 env var：**`ENABLE_RAG_WEB_SEARCH`**（来源：[https://docs.openwebui.com/troubleshooting/web-search/]，多处讨论确认此变量名）。

- 默认值：需要手动启用（默认关）
- 还需配置搜索引擎提供商（SearXNG、Brave、Bing 等），否则功能虽开但无法使用
- 本项目 `docker-compose.yml` 已包含 SearXNG 服务，配合 `SEARXNG_QUERY_URL` 使用

**用户级别"始终开启"**：目前没有 env var 可以让每个用户的"Web Search"按钮默认处于 ON 状态——这是用户设置，需用户自行在 Settings > Chat 中打开"Always-On Web Search"。管理员可在 Admin Panel 全局启用搜索引擎，但每次对话的搜索开关仍由用户控制。（来源：[Discussion #18756](https://github.com/open-webui/open-webui/discussions/18756)）

### 代码执行（Code Interpreter / Pyodide）

官方 env var：**`ENABLE_CODE_INTERPRETER`**（已在当前配置中，默认 `True`）。

来源：[https://docs.openwebui.com/reference/env-configuration/]：
- `ENABLE_CODE_INTERPRETER=True`（默认已开）
- `ENABLE_CODE_EXECUTION=True`（控制代码执行总开关）
- `CODE_EXECUTION_ENGINE=pyodide`（默认引擎，浏览器端 WebAssembly，无服务端风险）

**结论**：当前配置已包含 `ENABLE_CODE_INTERPRETER=true`，无需额外添加。

### 知识库 RAG

当前配置已包含 `ENABLE_RAG_HYBRID_SEARCH=true`（启用 BM25+向量混合检索）。

补充说明：RAG 功能（上传文档、知识库问答）默认在界面层是开放的，无需额外 env var。`ENABLE_RAG_HYBRID_SEARCH` 是质量增强选项，已在配置中。

### 中文 UI（`DEFAULT_LOCALE=zh-CN`）

当前配置已包含 `DEFAULT_LOCALE=zh-CN`。

**重要说明**：此变量是 `PersistentConfig`，写入数据库后对**新用户首次访问即生效**，显示中文界面。但若数据库已有历史记录（旧用户），其个人语言设置优先。全新部署（首次启动）`DEFAULT_LOCALE=zh-CN` 直接生效，小白用户无需手动改语言。

来源：[https://docs.openwebui.com/reference/env-configuration/]（DEFAULT_LOCALE，PersistentConfig 标注）

---

## 4. 隐藏复杂菜单

### Admin Panel 是否对普通用户可见？

**Admin Panel 只对 admin 角色用户可见**，普通 `user` 角色的头像菜单中不会出现 Admin Panel 入口。这是 Open WebUI RBAC 的默认行为，无需额外配置。

来源：[https://docs.openwebui.com/features/authentication-access/rbac/roles/]（admin 角色才有管理权限）

**单用户模式（`WEBUI_AUTH=false`）下**：所有访问者都是 admin，所以 Admin Panel 可见——但这对"自己用"的小白场景完全合理，可以直接调配置。

### Settings 中的 Connections / Pipelines 高级选项

Open WebUI **没有 `WEBUI_FEATURES_*` 系列环境变量**来隐藏 Settings 子项。Connections、Pipelines 等选项在 Settings 里对所有登录用户可见，目前无法通过 env var 隐藏。

可通过 `USER_PERMISSIONS_*` 系列变量限制功能使用权限，但不能隐藏菜单项。

**实用替代方案**：
- 多用户场景中，设 `DEFAULT_USER_ROLE=user` 可确保普通用户无 Admin Panel 访问权
- 单用户场景无需担心，只有一个人用

### 相关权限 env vars（USER_PERMISSIONS_* 系列）

来源：[https://docs.openwebui.com/features/authentication-access/rbac/permissions/]

```yaml
USER_PERMISSIONS_CHAT_FILE_UPLOAD=true   # 是否允许上传文件
USER_PERMISSIONS_CHAT_WEB_SEARCH=true    # 是否允许使用联网搜索
# 还有更多，完整列表见 env-configuration 文档
```

这些控制功能是否可用，而非界面显示隐藏。

---

## 5. 推荐 docker-compose env 增量（小白家庭部署模式）

以下是在当前已有配置基础上**追加**的 YAML 片段。适用场景：家庭单机或局域网部署，单人或信任用户使用。

```yaml
# ===== 在 open-webui service 的 environment 段追加以下内容 =====

      # --- 登录免除（single-user 模式）---
      # 小白价值：高 | 必须是全新安装（无历史用户数据）才能生效
      # 文档：https://docs.openwebui.com/reference/env-configuration/
      - WEBUI_AUTH=false

      # --- 预设默认模型 ---
      # 小白价值：高 | 值改为 hermes 实际暴露的 model id（通过 GET /v1/models 确认）
      # 文档：https://docs.openwebui.com/reference/env-configuration/
      - DEFAULT_MODELS=hermes-agent

      # 在模型选择器中置顶显示，方便快速找到
      # 小白价值：中
      - DEFAULT_PINNED_MODELS=hermes-agent

      # --- 联网搜索（配合已有 SearXNG 服务）---
      # 小白价值：高 | 启用后在 Admin Panel > Settings > Web Search 完成 provider 配置
      # 文档：https://docs.openwebui.com/troubleshooting/web-search/
      - ENABLE_RAG_WEB_SEARCH=true

      # --- 管理员账号预建（仅在保留认证时使用，WEBUI_AUTH=false 时可省略）---
      # 小白价值：中 | 防止首次访问时显示"注册管理员"页面
      # 配合 WEBUI_AUTH=true 使用；WEBUI_AUTH=false 则此两行删除
      # - WEBUI_ADMIN_EMAIL=admin@local.home
      # - WEBUI_ADMIN_PASSWORD=ChangeMe123!

      # --- PersistentConfig 覆盖保险 ---
      # 小白价值：低 | 如果之前启动过 webui 并有数据库残留，设此项让 env var 重新生效
      # 正常全新部署不需要；仅在"改了 env var 但界面不变"时临时加，生效后删除
      # - ENABLE_PERSISTENT_CONFIG=false

      # --- 多用户场景补充（WEBUI_AUTH=true 时）---
      # 小白价值：中 | 新用户默认待审核，管理员批准后才能使用，防止陌生人注册
      # - DEFAULT_USER_ROLE=pending
      # - ENABLE_SIGNUP=false   # 如不想对外开放注册
```

### 配置决策树

```
全新安装（无历史数据）？
  ├─ 是 → WEBUI_AUTH=false（一步到位，访问即用）
  │        + DEFAULT_MODELS=<模型id>
  │        + ENABLE_RAG_WEB_SEARCH=true（如有 SearXNG）
  └─ 否（已有用户数据）→ 不能用 WEBUI_AUTH=false
           用 WEBUI_ADMIN_EMAIL + WEBUI_ADMIN_PASSWORD 预建管理员
           + ENABLE_SIGNUP=false 防止外部注册
```

### 注意事项

1. `DEFAULT_MODELS` 的模型 ID 必须与 hermes 服务 `GET /v1/models` 返回的 `id` 字段完全一致
2. `WEBUI_AUTH=false` 生效前，确保 open-webui 数据卷是空的（`docker compose down -v` 清除）
3. 首次访问若出现认证错误，清除浏览器该站点的 Cookies 后重试（已知 bug #15254）
4. `PersistentConfig` 变量（`DEFAULT_MODELS`、`DEFAULT_LOCALE` 等）只在首次写入数据库时生效，若需重置需配合 `ENABLE_PERSISTENT_CONFIG=false` 或清库重启

---

## 参考来源

| 来源 | URL |
|------|-----|
| 官方 env 变量完整参考 | https://docs.openwebui.com/reference/env-configuration/ |
| 安全加固指南 | https://docs.openwebui.com/getting-started/advanced-topics/hardening/ |
| WEBUI_AUTH 无用户要求 | https://github.com/open-webui/open-webui/issues/9896 |
| 无登录部署讨论 | https://github.com/open-webui/open-webui/discussions/10982 |
| WEBUI_AUTH=false 前端 bug | https://github.com/open-webui/open-webui/discussions/15285 |
| Web Search 用户行为说明 | https://github.com/open-webui/open-webui/discussions/18756 |
| RBAC 权限文档 | https://docs.openwebui.com/features/authentication-access/rbac/permissions/ |
| Docker Model Runner 集成示例 | https://docs.docker.com/ai/model-runner/openwebui-integration/ |
