# OpenDeepSeek Onboarding Server

零依赖 Python HTTP Server，引导小白通过浏览器图形界面完成 API Key 配置并一键启动整套服务。

## 功能概览

| 端点 | 方法 | 说明 |
|---|---|---|
| `/` | GET | 返回 onboarding 单页 HTML |
| `/static/*` | GET | 静态资源（CSS / JS / 图片）|
| `/api/configure` | POST | 接收 API Key，写 .env，启动 docker compose |
| `/api/status` | GET | 查询启动状态，ready=true 时前端自动跳转 |

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
```

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
