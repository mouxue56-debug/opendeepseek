# OpenDeepSeek 路人一键部署说明

> 这份文档面向第一次看到 OpenDeepSeek 的普通用户。目标是：不懂 Docker、不懂 Agent 架构，也能照着做，在自己的电脑上跑起一个有真实 Agent 能力的 DeepSeek V4 助手。

---

## 一句话版本

先准备两样东西：

1. Docker Desktop 已经安装并启动。
2. DeepSeek API Key 已经拿到。

然后运行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

按提示填一次 DeepSeek API Key。安装完成后打开：

```text
http://localhost:3000
```

默认家庭模式不需要注册，进去就能和 `hermes-agent` 对话。

---

## 这个项目到底装了什么

OpenDeepSeek 不是“Open WebUI 直接接 DeepSeek”。默认链路是：

```text
浏览器 / 手机 PWA
      ↓
Open WebUI
      ↓
Hermes Smart Bridge
      ├─ 普通问答 → DeepSeek V4 Flash
      └─ 真任务 → Hermes Agent → DeepSeek V4 Flash
```

各层职责：

| 层 | 作用 | 用户看到什么 |
|---|---|---|
| Open WebUI | 聊天界面、历史记录、上传文件、PWA | 像 ChatGPT 一样打开网页用 |
| Hermes Smart Bridge | 把上传图片保存到本机并 OCR；普通问答直连 DeepSeek；真任务进 Hermes | 聊天更快，Agent 能力不丢 |
| Hermes Agent | Memory、Skills、Cron、Subagent、文件/终端工具 | “提醒我”“看桌面文件”“生成网页”能真执行 |
| DeepSeek V4 Flash | 便宜快速的推理模型 | 提供回答和 Agent 决策能力 |

容器启动后通常有三个核心服务：

| 容器 | 作用 | 端口 |
|---|---|---|
| `opendeepseek-webui` | 用户界面 | `127.0.0.1:3000` |
| `opendeepseek-hermes-bridge` | Smart Bridge：图片 OCR + 智能路由 | Docker 内网 `8765` |
| `opendeepseek-hermes` | Agent 内核 | `127.0.0.1:8642` |

---

## 安装前准备

### 1. 安装 Docker

macOS / Windows 用户建议直接安装 Docker Desktop：

```text
https://www.docker.com/products/docker-desktop/
```

安装后要打开 Docker Desktop，并等待它启动完成。

Linux 用户可用：

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

如果加了 docker 用户组，可能需要重新登录终端。

### 2. 获取 DeepSeek API Key

去 DeepSeek 平台创建 API Key：

```text
https://platform.deepseek.com/
```

安装向导只会要求粘贴一次 API Key。这个 key 会写入本机项目目录的 `.env`，不会提交到 GitHub。

---

## 推荐安装方式：远程一键

适合普通用户。复制这行到终端：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

脚本会做这些事：

1. 检查系统是 macOS / Linux / WSL2。
2. 检查 `git`、`curl`、`docker`、`docker compose`。
3. 让用户选择安装目录，默认是 `~/opendeepseek`。
4. 从 GitHub clone 项目。
5. 打开浏览器安装向导 `http://localhost:3001`。
6. 让用户输入 DeepSeek API Key。
7. 写入 `.env`。
8. 启动 Docker Compose。
9. 修复 Hermes 默认模型为 `deepseek-v4-flash`。
10. 等服务 healthy。
11. 打开 `http://localhost:3000`。

安装完成后，用户只需要记住：

```text
使用入口：http://localhost:3000
```

---

## API Key 输入引导页是什么

远程一键脚本和 `./setup.sh --web` 都会启动一个本地引导页：

```text
http://localhost:3001
```

这个页面只在首次配置或重新配置时使用，不是正式聊天入口。正式聊天入口仍然是：

```text
http://localhost:3000
```

引导页的作用：

1. 让用户粘贴 DeepSeek API Key。
2. 让用户选择默认模型，默认是 `deepseek-v4-flash`。
3. 自动生成 `HERMES_API_KEY` 和 `WEBUI_SECRET_KEY`。
4. 自动把用户家目录写成 `HERMES_HOST_DIR`，让 Hermes 在容器内通过 `/host` 访问本机文件。
5. 写入项目根目录 `.env`。
6. 执行 `docker compose up -d`。
7. 等待 Hermes 和 Open WebUI 健康检查通过。
8. 执行 Hermes 默认模型修复。
9. 就绪后跳转到 `http://localhost:3000`。

页面背后的文件：

| 文件 | 作用 |
|---|---|
| `onboarding/index.html` | API Key 输入和启动进度页面 |
| `onboarding/static/style.css` | 引导页样式 |
| `onboarding/server.py` | 本地 HTTP server，监听 `127.0.0.1:3001` |
| `setup.sh --web` | 启动 onboarding server |
| `OpenDeepSeek.command` | macOS 双击入口，内部运行 `./setup.sh --web` |

引导页的接口：

| 路径 | 方法 | 作用 |
|---|---|---|
| `/` | GET | 打开引导页 |
| `/api/configure` | POST | 接收 API Key 和模型名，写入 `.env`，启动 Docker |
| `/api/status` | GET | 前端轮询启动状态 |

安全边界：

- 只监听 `127.0.0.1:3001`，默认只能本机访问。
- API Key 只写入本机 `.env`。
- `.env` 已被 `.gitignore` 忽略，不应提交到 GitHub。
- 引导页不是长期服务，配置完成后可以关掉终端里的 onboarding 进程。

如果引导页没有自动打开，手动访问：

```text
http://localhost:3001
```

如果端口 3001 被占用，可以改 `onboarding/server.py` 里的 `PORT = 3001`，或关闭占用该端口的程序后重试。

---

## macOS 小白安装方式：双击版

如果用户拿到的是发布 zip 包：

1. 解压 `OpenDeepSeek.zip`。
2. 双击 `OpenDeepSeek.command`。
3. 浏览器会打开配置向导。
4. 粘贴 DeepSeek API Key。
5. 等待安装完成。
6. 打开 `http://localhost:3000` 使用。

`OpenDeepSeek.command` 本质上等价于：

```bash
./setup.sh --web
```

它适合不想碰命令行的 macOS 用户。

---

## 源码安装方式：适合想看代码的人

```bash
git clone https://github.com/mouxue56-debug/opendeepseek.git
cd opendeepseek
./setup.sh --web
```

如果不想用浏览器向导，也可以用命令行极简模式：

```bash
./setup.sh
```

高级模式会询问更多配置：

```bash
./setup.sh --advanced
```

---

## Docker 熟手安装方式

适合懂 Docker、想自己改 `.env` 的用户。

```bash
git clone https://github.com/mouxue56-debug/opendeepseek.git
cd opendeepseek
cp .env.example .env
```

编辑 `.env`，至少填：

```env
DEEPSEEK_API_KEY=sk-...
DEFAULT_MODEL=deepseek-v4-flash
WEBUI_AUTH=false
BIND_HOST=127.0.0.1
```

启动：

```bash
docker compose up -d
```

验证：

```bash
docker compose ps
bash scripts/smoke-test.sh
```

---

## 第一次打开后应该看到什么

打开：

```text
http://localhost:3000
```

默认应该看到：

- 模型已选择 `hermes-agent`。
- 页面是中文。
- 不需要注册登录。
- 输入框下方有中文建议卡片。
- 能直接发消息。

建议先发这句测试：

```text
项目链路真实测试：只回复 PROJECT_CHAIN_OK，不要解释。
```

如果返回 `PROJECT_CHAIN_OK`，说明：

```text
Open WebUI → Hermes Smart Bridge → DeepSeek V4 Flash
```

这条普通问答轻量链路通了。它会比完整 Agent 路径更快。

再发这句验证真 Agent 路径：

```text
请在 /host/OpenDeepSeek-Outputs/chain-test.txt 写入 PROJECT_AGENT_OK，只回复文件路径。
```

如果本机出现该文件，说明：

```text
Open WebUI → Hermes Smart Bridge → Hermes Agent → DeepSeek V4 Flash → /host 文件工具
```

这条执行链路也通了。

---

## 怎么确认它不是普通聊天工具

普通聊天工具只能回答。OpenDeepSeek 应该能做真实 Agent 动作。

可以测试这些 prompt：

```text
请查看 /host/Desktop，但不要移动或删除任何文件。先按类型总结我的桌面有什么。
```

```text
请在 /host/OpenDeepSeek-Outputs/test-site 里生成一个单文件中文网页 index.html，主题是 OpenDeepSeek。
```

```text
请创建一个 10 分钟后的提醒：回来检查 OpenDeepSeek 是否好用。请实际使用 cron 工具创建，并告诉我任务 ID。
```

```text
请记住：我偏好中文、直接、少废话、要真执行不要只解释。
```

这些能力来自 Hermes：

- 文件/终端工具：能读写 `/host` 下的文件。
- Cron：能创建后台提醒任务。
- Memory：能跨会话记住偏好。
- Skills：能沉淀方法和模板。
- Subagent：能拆分复杂任务并行执行。

---

## 图片上传是怎么处理的

DeepSeek V4 Flash 文本接口不应该直接接收 OpenAI 风格的 `image_url` content part。否则会出现类似错误：

```text
unknown variant image_url, expected text
```

OpenDeepSeek 的处理方式是加一层 Hermes Smart Bridge：

1. Open WebUI 正常接收用户上传图片。
2. Smart Bridge 把图片保存到本机：

```text
/host/OpenDeepSeek-Inputs/...
```

3. Smart Bridge 使用中文/英文 OCR 提取截图文字。
4. Smart Bridge 把请求改写成纯文本路径 + OCR 摘要。
5. Hermes Agent 再把任务交给 DeepSeek V4 Flash。

所以用户可以继续上传截图、证据图、网页图。项目不要求用户“别传图片”。

---

## 本机文件权限说明

默认家庭模式会把用户家目录挂到 Hermes 容器内：

```text
宿主机：/Users/你的用户名
容器内：/host
```

所以用户可以让 Agent 访问：

```text
/host/Desktop
/host/Documents
/host/Downloads
/host/OpenDeepSeek-Outputs
```

这也是它能“看桌面有什么文件”“生成网页到本机”的原因。

如果用户想收窄权限，可以把 `.env` 改成：

```env
HERMES_HOST_DIR=./agent-files
```

然后重启：

```bash
docker compose up -d hermes hermes-bridge open-webui
```

---

## 安全边界

默认家庭模式：

```env
WEBUI_AUTH=false
BIND_HOST=127.0.0.1
```

含义：

- 不需要登录。
- 只能本机访问。
- 适合个人电脑、家庭电脑、本机测试。

不要做这件事：

```env
WEBUI_AUTH=false
BIND_HOST=0.0.0.0
```

这等于把没有密码的 Agent 暴露给外部网络。别人可能让它读取或修改 `/host` 下的文件，也会消耗你的 DeepSeek API 额度。

如果要公网部署，至少要：

```env
WEBUI_AUTH=true
BIND_HOST=0.0.0.0
```

并且在前面加反向代理、HTTPS、访问控制或 Tailscale。

---

## 手机访问和 Tailscale

如果只想自己手机访问，不建议直接公网暴露。推荐 Tailscale。

大致流程：

1. 电脑和手机都安装 Tailscale。
2. 登录同一个 Tailscale 账号。
3. 电脑上查看 Tailscale IP：

```bash
tailscale ip -4
```

4. `.env` 里设置：

```env
BIND_HOST=0.0.0.0
```

5. 重启服务：

```bash
docker compose down
docker compose up -d
```

6. 手机上访问：

```text
http://<电脑的 tailscale-ip>:3000
```

Tailscale 是私有网络，不等于把端口暴露到公网。

---

## 常用命令

进入项目目录：

```bash
cd ~/opendeepseek
```

查看状态：

```bash
docker compose ps
```

查看日志：

```bash
docker compose logs -f
```

停止：

```bash
docker compose down
```

启动：

```bash
docker compose up -d
```

跑项目级验证：

```bash
bash scripts/smoke-test.sh
```

---

## 升级

```bash
cd ~/opendeepseek
git pull origin main
docker compose pull
docker compose up -d --build
bash scripts/smoke-test.sh
```

如果改了 `.env`，推荐完整重建：

```bash
docker compose down
docker compose up -d --build
```

不要只依赖 `docker compose restart`，它不会重新读取全部环境变量。

---

## 卸载

只停止服务，不删数据：

```bash
docker compose down
```

删除容器和数据卷：

```bash
docker compose down -v
```

注意：`down -v` 会删除 Open WebUI 对话历史、上传文件索引和 Hermes 数据。

---

## 常见问题

### Docker 没启动

现象：

```text
Cannot connect to Docker daemon
```

处理：

- macOS / Windows：打开 Docker Desktop，等它启动完成。
- Linux：运行 `sudo systemctl start docker`。

### 3000 端口被占用

现象：

```text
bind: address already in use
```

处理：先确认是不是旧服务还在跑。

```bash
docker compose ps
docker compose down
```

如果确实有别的软件占用 3000，可以改 `docker-compose.yml` 里的端口。

### 浏览器打开白屏

处理：

```bash
docker compose ps
docker compose logs open-webui --tail 100
```

首次启动 Open WebUI 可能需要几十秒。等容器 healthy 后刷新页面。

### 模型列表空白

检查 Open WebUI 是否指向 Smart Bridge：

```bash
docker compose exec -T open-webui sh -lc 'env | grep OPENAI_API_BASE_URL'
```

应该看到：

```text
OPENAI_API_BASE_URL=http://hermes-bridge:8765/v1
```

### 上传图片后报 `image_url`

说明请求没有走 Smart Bridge，或容器没有重建。

处理：

```bash
docker compose up -d --build hermes-bridge open-webui
docker compose logs hermes-bridge --tail 50
```

发送图片请求时日志应出现：

```text
sanitized 1 image(s) for /v1/chat/completions
```

### Agent 不能看本机文件

检查 `/host` 是否挂载：

```bash
docker compose exec -T hermes test -d /host && echo HOST_READY
```

如果没有，检查 `.env`：

```env
HERMES_HOST_DIR=/Users/你的用户名
```

然后重启：

```bash
docker compose down
docker compose up -d
```

---

## 发布者 checklist

项目维护者在发布给路人前，至少要确认：

```bash
bash -n install.sh setup.sh scripts/smoke-test.sh
docker compose config >/tmp/opendeepseek-compose-config.out
bash scripts/smoke-test.sh
```

还要检查：

- GitHub `main` 分支包含 `bridge/` 目录。
- GitHub `main` 分支里的 `docker-compose.yml` 已让 Open WebUI 指向 `http://hermes-bridge:8765/v1`。
- `README.md` 的一键命令指向正确仓库。
- `.env` 没有被提交。
- 默认 `WEBUI_AUTH=false` 时，`BIND_HOST` 仍是 `127.0.0.1`。
- `docs/ONE-CLICK.md`、`docs/INSTALL.md`、`docs/SECURITY.md` 与当前架构一致。

最终发布后，最好在一台干净机器上跑一遍：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

这一步最重要，因为用户拿到的是 GitHub `main` 上的版本，不是维护者本机 worktree。
