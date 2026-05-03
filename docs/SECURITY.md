# 安全配置指南

> 本指南对应 OpenDeepSeek v0.2.x。  
> 默认部署模式针对**本地家庭使用**优化，云端 / 公网部署必须按本指南加固。

---

## 1. 部署模式与默认安全等级

| 模式 | `WEBUI_AUTH` | `BIND_HOST` | 适合场景 |
|---|---|---|---|
| 家庭单用户（默认） | `false` | `127.0.0.1` | 本机使用、Tailscale 私有网络 |
| 团队多用户 | `true` | `127.0.0.1` 或 `0.0.0.0`（配反向代理） | 办公室局域网 / 公网（需加固） |
| ⚠️ **公网无认证（禁止）** | `false` | `0.0.0.0` | **绝不允许** |

`setup.sh` 默认选项 1（家庭单用户）= `WEBUI_AUTH=false` + `BIND_HOST=127.0.0.1`，仅本机访问。

---

## 2. 风险地图

| 风险 | 触发条件 | 后果 | 缓解 |
|---|---|---|---|
| 越权对话 | `WEBUI_AUTH=false` + `BIND_HOST=0.0.0.0` 暴露公网 | 任何人都能用你的 DeepSeek API key 对话 | 改 `WEBUI_AUTH=true` 或 `BIND_HOST=127.0.0.1` |
| API Key 盗刷 | 越权访问后通过 chat 接口大量调用 | DeepSeek 账户余额被盗刷 | 同上 + 在 DeepSeek 控制台设置月度上限 |
| 知识库泄漏 | 越权访问 + 上传过敏感 PDF | 内部资料被读取 | 同上 |
| 容器逃逸 | 启用 SearXNG `--profile full` 但未限 cap | 较低风险（SearXNG 沙箱有限） | 保持默认 cap_drop 配置 |
| Bot 滥用 | 启用 IM 桥接（钉钉/飞书等）但未配 allowlist | 任何 IM 用户都能调用你的 Agent | 设置 `*_ALLOWED_USERS` 白名单 |

---

## 3. 公网部署加固清单

按顺序操作：

### 3.1 启用账号登录
```ini
# 编辑 .env
WEBUI_AUTH=true
ENABLE_SIGNUP=false   # 禁止外部注册（推荐）
```
首次启动时会要求注册管理员账号。后续用户由管理员邀请。

### 3.2 绑定全网（让反向代理能访问）
```ini
BIND_HOST=0.0.0.0
```

### 3.3 配置反向代理
**绝不要**直接把 `0.0.0.0:3000` 暴露到公网。在前面加一层 Nginx / Caddy / Traefik，做：
- HTTPS 终结
- IP 白名单（如只允许公司办公 IP）
- HTTP Basic Auth 兜底
- 日志审计

最小 Caddy 示例（`Caddyfile`）：
```caddy
yourdomain.com {
  reverse_proxy 127.0.0.1:3000
  basicauth {
    admin <bcrypt-hash>
  }
}
```

### 3.4 重启服务
```bash
docker compose down
docker compose up -d
```

---

## 4. Tailscale / Zero Trust 推荐

如果你只想"远程访问"而不是"公开访问"，**强烈推荐用 Tailscale**：

```bash
# 安装
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# 看自己的 Tailscale IP
tailscale ip -4
```

把 `BIND_HOST` 设成 `0.0.0.0`（让 Tailscale 网卡能访问），但**不在公网防火墙开放 3000 端口**。手机 / 异地电脑通过 Tailscale 隧道访问 `http://<tailscale-ip>:3000` 即可。

这种方式无需反向代理 + Basic Auth，因为 Tailscale 本身就是身份认证 + 加密隧道。

---

## 5. API Key 处理

### `.env` 文件
- mode 600（`setup.sh` 自动设置）
- 在 `.gitignore`，**绝不入 git**
- 备份时用 `scripts/backup.sh`，归档同样保持 600

### DeepSeek API Key
- 在 [platform.deepseek.com](https://platform.deepseek.com/api_keys) 设月度消费上限
- 定期 rotate（建议 90 天一次）
- 一个项目一个 key，不混用

### Hermes / WebUI Internal Keys
- 自动生成（`openssl rand -hex 32`）
- 每次重新部署都会变
- 仅容器间通信使用，不暴露给用户

---

## 6. IM 桥接安全

启用钉钉 / 飞书 / 企微 / QQ Bot 时：

### 6.1 用户白名单
每个 IM 桥接的环境变量都有 `*_ALLOWED_USERS`，**务必填具体用户 ID**：
```ini
DINGTALK_ALLOWED_USERS=user_id_1,user_id_2
```
不填 = 任何人都能 @bot 调用你的 Agent + 烧你的 API quota。

### 6.2 回调签名
钉钉 / 飞书等 IM 平台会签名 webhook 请求。Hermes Agent v0.11 默认验证签名（依赖 `*_SECRET`）。**不要自己关闭签名验证**。

### 6.3 IP 白名单（高级）
在反向代理层只放行 IM 平台的官方 IP 段。各平台 IP 段：
- 钉钉：[官方文档](https://open.dingtalk.com/document/orgapp/event-subscription-faq)
- 飞书：[官方文档](https://open.feishu.cn/document/server-docs/event-subscription-guide/event-subscription-configure-/encrypt-key-encryption-configuration-case)
- 企微：[官方文档](https://developer.work.weixin.qq.com/document/path/90930)

---

## 7. 漏洞披露

发现 OpenDeepSeek 安全漏洞？请：
1. **不要**在 GitHub Issue 公开披露
2. 邮件至 security@opendeepseek.example（占位，实际维护者填）
3. 给 90 天响应窗口

---

## 8. 检查清单

部署后跑一遍：

```bash
# 1. 确认 .env 权限
ls -la .env  # 应该是 -rw------- (mode 600)

# 2. 确认 .env 在 .gitignore
git check-ignore .env  # 应该输出 .env

# 3. 确认端口绑定
docker compose ps
# 看 PORTS 列：127.0.0.1:3000-> 是家庭模式；0.0.0.0:3000-> 是全网（需配反向代理）

# 4. 确认 WEBUI_AUTH 状态
curl -s http://localhost:3000/api/config | python3 -c "import json,sys;print('auth:', json.load(sys.stdin)['features']['auth'])"

# 5. 确认 hermes 不直接暴露
curl -s http://localhost:8642/v1/models -H "Authorization: Bearer wrong-key"
# 应返回 401，不能用 wrong-key 拿到模型列表
```

---

## 9. 进一步阅读

- [Open WebUI 安全加固官方文档](https://docs.openwebui.com/getting-started/advanced-topics/hardening/)
- [Docker 容器安全最佳实践](https://docs.docker.com/engine/security/)
- [Caddy 反向代理 HTTPS 配置](https://caddyserver.com/docs/quick-starts/reverse-proxy)
