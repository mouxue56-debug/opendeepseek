# OpenDeepSeek Onboarding Server

零依赖 Python HTTP Server，引导小白通过浏览器图形界面完成 API Key 配置，并一键启动 Open WebUI + Hermes Smart Bridge + Hermes Agent + DeepSeek V4 Flash。

## 功能概览

| 端点 | 方法 | 说明 |
|---|---|---|
| `/` | GET | 返回 onboarding 单页 HTML |
| `/static/*` | GET | 静态资源（CSS / JS / 图片）|
| `/api/configure` | POST | 接收 API Key，写 .env，启动 docker compose |
| `/api/status` | GET | 查询启动状态，ready=true 时前端自动跳转 |

## 用户会看到什么

访问 `http://localhost:3001` 后，用户先看到一个中文项目介绍页，包含：

- OpenDeepSeek 是什么：Open WebUI + Smart Bridge + Hermes Agent + DeepSeek V4 Flash。
- 为什么不是普通聊天工具：普通问答轻量直连，真实任务路由到 Hermes。
- 怎么运行：一键安装、本地仓库启动、手动 Docker Compose 三种方式。

随后用户点击“填写 API Key 并启动”，只需要做三件事：

1. 点击“填写 API Key 并启动”。
2. 粘贴 DeepSeek API Key。
3. 选择模型，默认 `deepseek-v4-flash`，然后点击“激活并启动”。

页面会展示启动阶段：

```text
写入配置文件 → 启动 Docker 容器 → 等待服务就绪 → 跳转 Open WebUI
```

完成后自动跳转：

```text
http://localhost:3000
```

## 快速运行

```bash
python3 onboarding/server.py
```

浏览器会自动打开 http://localhost:3001（macOS / Linux / Windows 均支持）。  
若未自动打开，手动访问该地址即可。

**依赖**：仅 Python 3.6+ 标准库，无需 `pip install` 任何包。

## 集成到 setup.sh

在 `setup.sh` 末尾加入以下片段：

```bash
#!/usr/bin/env bash
# ... 原有内容 ...

echo "启动 Onboarding 向导..."
# 后台启动 onboarding server
python3 "$(dirname "$0")/onboarding/server.py" &
ONBOARDING_PID=$!

# 等待用户完成配置（轮询 /api/status）
echo "请在浏览器中完成配置，然后继续..."
until curl -sf http://localhost:3001/api/status | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('ready') else 1)" 2>/dev/null; do
  sleep 3
done

# 关闭 onboarding server（可选，用户已跳转到 :3000）
kill "$ONBOARDING_PID" 2>/dev/null || true
echo "✅ 配置完成，服务已在 http://localhost:3000 运行"
```

或者更简单，直接前台运行（用户配置完毕后 Ctrl+C）：

```bash
python3 onboarding/server.py
```

## 端口说明

| 端口 | 服务 |
|---|---|
| **3001** | Onboarding Server（本文件）|
| 3000 | Open WebUI（配置完成后跳转目标）|
| 8642 | Hermes API Gateway |

## 配置写入位置

`/path/to/project/.env`（项目根目录），包含：

```env
DEEPSEEK_API_KEY=sk-xxxx
DEFAULT_MODEL=deepseek-v4-flash
HERMES_API_KEY=<自动生成 64 位随机 hex>
WEBUI_SECRET_KEY=<自动生成 64 位随机 hex>
HERMES_HOST_DIR=/Users/你的用户名
```

Docker Compose 随后会启动：

```text
普通问答：Open WebUI → Hermes Smart Bridge → DeepSeek V4 Flash
真任务：  Open WebUI → Hermes Smart Bridge → Hermes Agent → DeepSeek V4 Flash
```

其中 Smart Bridge 会处理 Open WebUI 上传的图片：保存到 `/host/OpenDeepSeek-Inputs`，OCR 后把图片改写成文本路径摘要；普通问答直连 DeepSeek，真任务再交给 Hermes。

## 安全说明

- **仅监听本机（127.0.0.1:3001）**，不对外暴露。
- API Key 写入本机 `.env` 文件，**不会经过任何网络**，不会上传。
- `HERMES_API_KEY` 和 `WEBUI_SECRET_KEY` 使用 Python `secrets.token_hex(32)` 自动生成（64 位加密随机数），每次初次配置生成后保持不变（幂等写入）。
- 建议配置完成后，在防火墙中关闭端口 3001（或直接停止 onboarding server）。

## 故障排除

| 现象 | 解决方法 |
|---|---|
| 浏览器打不开 3001 | 确认 `python3 onboarding/server.py` 已在终端运行 |
| 激活后一直转圈 | 检查 Docker Desktop 是否已启动；运行 `docker ps` 查看容器状态 |
| docker compose 报错 | 页面会显示完整错误日志；也可运行 `docker compose logs` 查看 |
| 重复配置 | 直接再次粘贴新 Key 并点击激活，.env 会覆盖更新 |
