# OpenDeepSeek Debug Summary（自主 10 轮调试报告）

**调试时间**：2026-04-29  
**分支**：`claude/stoic-rhodes-f8b694`  
**最终状态**：全部 10 轮完成，smoke-test 7/7 PASS，git status 干净

---

## 总览

| 项目 | 数量 |
|------|------|
| 总 Bug 数 | 11 |
| 已修复 | 11 |
| 残留风险 | 1 项（低风险） |
| 新 Commit 数 | 10 |
| smoke-test 通过率 | 7/7 |

---

## 每轮关键发现与修复

### Round 1 - 静态校验 docker-compose.yml
- `searxng/` 目录不存在（bind-mount 会失败）→ 创建目录
- `DEFAULT_MODEL` 硬编码，未读取 `${DEFAULT_MODEL}` 变量 → 改为环境变量插值
- README.md / docs/README.md 端口写为 `:8080`（实际绑定 `:3000`）→ 修正端口

### Round 2 - 静态校验 setup.sh
- SKIP_CONFIG 分支 `grep | cut` 管道无法处理 trailing space，`|| echo fallback` 永不触发 → 加 `tr -d '[:space:]'` + 改为 `${var:-fallback}` 语法

### Round 3 - 文档完整性
- `docs/README.md` 和 `docs/FAQ.md` 内部链接带多余 `docs/` 前缀（会解析为 `docs/docs/xxx`）→ 去掉前缀
- `docs/FAQ.md` IM-BRIDGE.md 锚链接 `#钉钉` 不匹配实际 GFM anchor → 修正锚点格式

### Round 4 - setup.sh 干跑测试
- 无新 bug，mock docker 验证 6 阶段流程和 .env 生成均正确

### Round 5 - 真 docker compose up 启动
- `command: gateway run` 缺失（hermes 不以 API gateway 模式启动）→ 补充 command
- **核心 bug**：hermes 容器内无 `curl`，healthcheck 用 `CMD curl` 导致永远 unhealthy → open-webui depends_on 始终等待失败 → 改为 `CMD-SHELL python3 urllib.request`

### Round 6 - smoke-test.sh 端到端（含真 LLM 调用）
- smoke-test 第 5 项检查 `/v1/models` 响应含 "deepseek"，但 hermes 返回 `"id": "hermes-agent"`（代理自身 ID）→ 改为检查 OpenAI compat 结构（`"object": "list"` 或 `"data"`）
- 端到端 DeepSeek API 调用成功，最终 7/7 PASS

### Round 7 - SearXNG --profile full
- searxng image tag `2024.12.16-0` 不存在于 Docker Hub → 改为 `2026.4.28-ed5955a5c`
- searxng 主机端口 8888 被 OrbStack tinyproxy 占用 → 改为 8889（同步更新 settings.yml + FAQ.md）

### Round 8 - 容器间网络互通
- 无问题：`open-webui → hermes:8642/health` 容器 DNS 解析和 HTTP 通信均正常

### Round 9 - setup.sh 重跑（SKIP_CONFIG 分支）
- 无问题：`printf "N\n" | bash setup.sh` 正确跳过配置、读取现有 .env、启动所有服务

### Round 10 - 综合 review（本文档）

---

## 残留风险

1. **SearXNG 非关键引擎加载失败**（ahmia、torch、wikidata）：属 SearXNG 上游问题，不影响核心搜索功能，可忽略。

---

## 用户回家最快走通步骤

1. **确认 .env 已配置**（包含真实 `DEEPSEEK_API_KEY`，已就绪）
2. **启动服务**：在项目根目录执行 `./setup.sh`，回答 `N` 保留现有配置，等待 2 分钟
3. **访问 WebUI**：打开浏览器访问 `http://localhost:3000`，注册管理员账号，开始对话

> 或直接运行：`docker compose up -d` 然后访问 http://localhost:3000
