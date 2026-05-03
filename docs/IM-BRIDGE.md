# IM 桥接配置指南

> 把 OpenDeepSeek 接入到你公司/家庭的即时通讯工具，让 AI 能在工作群里、邮件里、QQ 里直接对话。

本文档面向 OpenDeepSeek 用户，介绍如何将 Hermes Agent v0.11 支持的 IM 平台桥接到你的 AI 系统。本项目精选 5 个对中国用户最友好的平台：**钉钉、飞书、企业微信、邮件、QQ Bot**。配置方式统一：在 `.env` 填入对应凭证，执行 `docker compose restart hermes` 即可生效。

---

## 1. 钉钉机器人

钉钉是国内企业办公场景覆盖最广的平台，适合把 AI 接入部门群、项目群，实现群内智能问答。

### 申请凭证
1) 打开 [钉钉开发者后台](https://open-dev.dingtalk.com/)，登录企业管理员账号
2) 进入「应用开发」→「企业内部应用」→「创建应用」
3) 填写应用名称（如"OpenDeepSeek AI"），选择应用类型为"机器人"
4) 创建完成后，进入「凭证与基础信息」页面，复制以下两项：
   - **Client ID**（即 AppKey）
   - **Client Secret**（点击"查看"按钮复制）

### 配置 .env

```env
# 钉钉机器人
DINGTALK_CLIENT_ID=your_client_id_here
DINGTALK_CLIENT_SECRET=your_client_secret_here
```

### 部署生效

```bash
cd /path/to/opendeepseek
docker compose restart hermes
```

### 测试方法
- 在钉钉群里 @机器人名称，发送任意问题（如"你好，能帮我总结一下今天的任务吗？"）
- 观察群内是否收到 AI 回复
- 如无回复，检查 Hermes 容器日志：`docker logs opendeepseek-hermes-1`

---

## 2. 飞书机器人

飞书（Lark）在字节系企业和互联网团队中普及率高，机器人配置流程与钉钉类似，适合技术团队使用。

### 申请凭证
1) 打开 [飞书开放平台](https://open.feishu.cn/)，用企业管理员账号登录
2) 进入「开发者后台」→「创建企业自建应用」
3) 填写应用名称，添加「机器人」能力到应用
4) 进入「凭证与基础信息」，复制：
   - **App ID**
   - **App Secret**
5) 进入「事件与回调」→ 开启机器人回调，配置请求 URL（需公网可访问，如已部署 OpenDeepSeek 则填入对应地址）

### 配置 .env

```env
# 飞书机器人
FEISHU_APP_ID=your_app_id_here
FEISHU_APP_SECRET=your_app_secret_here
```

### 部署生效

```bash
docker compose restart hermes
```

### 测试方法
- 在飞书群聊中 @机器人，发送消息测试
- 或在机器人私聊会话中直接提问
- 检查飞书开放平台「事件与回调」页面的推送日志，确认消息已送达

---

## 3. 企业微信（WeCom）

企业微信是腾讯系企业沟通工具，与微信互通，适合需要对接外部客户或微信生态的团队。

### 申请凭证
1) 打开 [企业微信管理后台](https://work.weixin.qq.com/)，用管理员账号登录
2) 进入「应用管理」→「自建」→「创建应用」
3) 填写应用名称，上传图标，选择可见范围
4) 创建完成后，进入应用详情页，复制：
   - **AgentId**（即 Bot ID）
   - **Secret**（点击"查看"按钮，需企业微信客户端扫码确认）

### 配置 .env

```env
# 企业微信
WECOM_BOT_ID=your_agentid_here
WECOM_SECRET=your_secret_here
```

### 部署生效

```bash
docker compose restart hermes
```

### 测试方法
- 在企业微信内部群或应用消息会话中 @应用名称
- 或在企业微信客户端直接打开该应用聊天窗口发送消息
- 注意：企业微信外部群（含微信联系人）暂不支持机器人主动回复

---

## 4. 邮件（IMAP/SMTP）

邮件是最通用的异步沟通方式，适合个人用户或不想依赖即时通讯平台的场景。AI 会定时读取收件箱，对每封邮件进行回复。

### 通用配置

```env
# 邮件服务
EMAIL_ADDRESS=your_email@example.com
EMAIL_PASSWORD=your_password_or_auth_code
EMAIL_IMAP_HOST=imap.example.com:993
EMAIL_SMTP_HOST=smtp.example.com:465
```

### 主流邮箱服务商配置对照

| 服务商 | IMAP 服务器 | SMTP 服务器 | 特殊说明 |
|--------|-------------|-------------|----------|
| **QQ 邮箱** | `imap.qq.com:993` | `smtp.qq.com:465` | 密码处填「授权码」，不是 QQ 登录密码 |
| **网易 163** | `imap.163.com:993` | `smtp.163.com:465` | 需开启 IMAP/SMTP 服务，使用授权码 |
| **阿里云企业邮** | `imap.qiye.aliyun.com:993` | `smtp.qiye.aliyun.com:465` | 管理员后台开启客户端授权 |
| **腾讯企业邮** | `imap.exmail.qq.com:993` | `smtp.exmail.qq.com:465` | 需管理员在后台开启 API 接口权限 |

### 获取授权码的方法（以 QQ 邮箱为例）
1) 登录 QQ 邮箱网页版
2) 进入「设置」→「账户」→「POP3/IMAP/SMTP/Exchange/CardDAV/CalDAV服务」
3) 开启「IMAP/SMTP服务」，点击「生成授权码」
4) 用手机短信验证后，复制 16 位授权码填入 `.env` 的 `EMAIL_PASSWORD`

### 部署生效

```bash
docker compose restart hermes
```

### 测试方法
- 用另一个邮箱地址发送邮件到配置的 `EMAIL_ADDRESS`
- 等待 1-3 分钟，查看是否收到 AI 的自动回复
- 首次配置建议发送简单问题（如"你好"），验证通道是否正常

---

## 5. QQ Bot（QQ 官方机器人）

QQ 官方机器人适合面向 QQ 群或频道的场景，个人开发者可申请 sandbox 环境测试，正式部署需通过审核。

### 申请凭证
1) 打开 [QQ 开放平台](https://q.qq.com/)，用 QQ 账号登录
2) 进入「机器人」→「创建机器人」
3) 填写机器人名称、图标、介绍，选择机器人类型
4) 创建完成后，进入「开发」→「开发设置」，复制：
   - **App ID**
   - **Client Secret**
5) 在「功能」页面添加需要的权限（如"群聊消息"、"频道消息"）
6) 提交审核（sandbox 环境可跳过，但仅限测试）

### 配置 .env

```env
# QQ 官方机器人
QQ_APP_ID=your_app_id_here
QQ_CLIENT_SECRET=your_client_secret_here
```

### 部署生效

```bash
docker compose restart hermes
```

### 测试方法
- 在 QQ 群或频道中 @机器人名称
- 或在机器人私聊会话中发送消息
- Sandbox 环境下，只能邀请测试号加入的群/频道中测试
- 正式环境需等待审核通过后，机器人才能被邀请加入普通群

---

## 常见问题

### 可以同时启用多个平台吗？
可以。在 `.env` 中同时填写多个平台的凭证，Hermes 会自动初始化所有已配置的桥接。建议首次配置时先启用一个平台验证通，再逐步添加其他平台。

### 重启后没有生效？
1) 确认 `.env` 文件位于项目根目录（与 `docker-compose.yml` 同级）
2) 确认凭证值没有多余的空格或引号
3) 查看 Hermes 容器日志：`docker logs opendeepseek-hermes-1 | grep -i "bridge\|im\|dingtalk\|feishu\|wecom\|email\|qq"`
4) 确认对应平台的回调 URL 已正确配置（飞书/钉钉需要公网可访问的地址）

### 凭证泄露了怎么办？
立即在对应平台后台重置 Secret/AppSecret，更新 `.env` 后重启容器。`.env` 文件已加入 `.gitignore`，不会提交到 Git，但请勿将其发送给他人或上传到公共网盘。

---

## 为什么不支持 Telegram / WhatsApp / iMessage？

本项目聚焦中国用户最常用的沟通场景，未纳入以下平台的原因：

- **Telegram**：在中国大陆无法直接访问，需要代理，不适合企业办公场景
- **WhatsApp**：主要面向海外用户，国内普及率极低，且 Business API 申请门槛高
- **iMessage**：仅限 Apple 生态，无公开 Bot API，无法以标准方式接入第三方 AI

对于以上平台有需求的用户，建议通过邮件桥接作为通用替代方案，或自行扩展 Hermes Agent 的适配器。优先使用本文档介绍的 5 个本土方案，配置简单、网络稳定、合规可控。

---

*文档版本：v1.0 | 适用 OpenDeepSeek ≥ v0.2.0 | Hermes Agent ≥ v0.11.0*
