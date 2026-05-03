# OpenDeepSeek 安装指南

> 一键部署本地 Agentic ChatGPT 替代品  
> 架构（v0.4.0 默认）：Open WebUI ⟶ Hermes Agent ⟶ DeepSeek V4 Flash  
> Hermes 默认启用，负责 Memory / Skills / Cron / Subagent / IM 桥接

---

## 1. 系统要求

| 项目 | 最低要求 |
|------|---------|
| Docker | 20.10 或更高版本 |
| Docker Compose | v2（`docker compose` 命令可用） |
| 内存 | 4 GB RAM |
| 磁盘空间 | 10 GB 可用空间 |
| 网络 | 可访问 Docker Hub 和 GitHub |

**检查命令：**

```bash
docker --version          # 应显示 20.10+
docker compose version    # 应显示 v2.x.x
docker info               # 确认 Docker daemon 正在运行
```

---

## 2. 一键安装（推荐）

```bash
# 1. 克隆仓库
git clone https://github.com/mouxue56-debug/opendeepseek.git
cd opendeepseek

# 2. 运行安装脚本
chmod +x setup.sh
./setup.sh --web
```

`setup.sh` 会自动完成以下操作：

1. 检查 Docker 和 Docker Compose 是否已安装
2. 复制 `.env.example` 为 `.env`（如不存在）
3. 拉取最新 Docker 镜像
4. 启动 Hermes Agent + Open WebUI
5. 修复 Hermes 默认模型为 DeepSeek V4 Flash / Pro
6. 等待健康检查通过并打印访问地址

macOS 用户也可以双击项目根目录的 `OpenDeepSeek.command`，效果等同于执行 `./setup.sh --web`。

安装完成后，终端会显示：

```
✅ OpenDeepSeek 启动成功！
🌐 访问地址：http://localhost:3000
🔑 家庭模式默认无需注册，打开即可对话
```

---

## 3. 手动安装

如果你偏好手动控制每一步，或一键脚本在你的环境遇到问题，可按以下步骤操作：

### 3.1 克隆仓库

```bash
git clone https://github.com/mouxue56-debug/opendeepseek.git
cd opendeepseek
```

### 3.2 配置环境变量

```bash
# 复制示例配置文件
cp .env.example .env

# 编辑配置（可选：修改端口、模型参数等）
nano .env   # 或 vim / 任意编辑器
```

`.env` 中关键配置项：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `DEEPSEEK_API_KEY` | DeepSeek API Key（必填） | — |
| `DEFAULT_MODEL` | 默认加载的模型 | `deepseek-v4-flash` |
| `HERMES_API_KEY` | Hermes 内部网关密钥（自动生成） | 32 位随机串 |
| `WEBUI_SECRET_KEY` | Open WebUI 会话密钥（自动生成） | 32 位随机串 |
| `ENABLE_CHINA_MODE` | 中文优化模式（启用 SearXNG） | `true` |

> **修改端口** 不在 `.env` 中——请编辑 `docker-compose.yml` 的 `ports:` 段（默认 `3000:8080` 和 `8642:8642`）。

### 3.3 启动服务

```bash
docker compose up -d
```

`-d` 表示后台运行。首次启动会拉取约 3-5 GB 的镜像，根据网络速度可能需要 5-15 分钟。

### 3.4 查看启动状态

```bash
docker compose ps          # 查看容器状态
docker compose logs -f     # 实时查看日志（Ctrl+C 退出）
```

所有容器状态显示 `healthy` 或 `running` 即表示启动成功。

---

## 4. 验证安装

### 4.1 访问界面

打开浏览器，访问：

```
http://localhost:3000
```

### 4.2 登录模式

默认家庭模式（`WEBUI_AUTH=false`）不需要注册，打开即可对话。  
如果你在 `.env` 中设置了 `WEBUI_AUTH=true`，首次访问时需要注册第一个管理员账号。

```
用户名：admin（或任意）
邮箱：your@email.com
密码：********（8位以上）
```

### 4.3 确认 Hermes 模型连接

1. 登录后点击右上角头像 → **Admin Panel**
2. 左侧菜单选择 **Settings → Connections**
3. 在 **OpenAI API** 或 **Direct Connections** 区域，确认连接指向 `http://hermes:8642/v1`
4. 模型列表中应包含 `hermes-agent`，这是 Open WebUI 调用 Hermes Agent 的入口

如果 Hermes 未显示，请检查：

```bash
docker compose logs hermes   # 查看 Hermes 容器日志
```

---

## 5. 升级流程

升级时用户数据（对话历史、知识库、配置）**不会丢失**。

```bash
# 1. 进入项目目录
cd opendeepseek

# 2. 拉取最新代码
git pull origin main

# 3. 拉取最新镜像
docker compose pull

# 4. 重新启动服务（数据卷自动保留）
docker compose up -d
```

**升级后验证：**

```bash
docker compose ps
# 确认所有容器状态正常
```

---

## 6. 卸载

⚠️ **警告：以下命令会删除所有数据，包括对话历史、上传文件和知识库！**

```bash
cd opendeepseek
docker compose down -v
```

如需保留数据，仅停止服务（不删除卷）：

```bash
docker compose down
```

彻底清理（含镜像）：

```bash
docker compose down -v --rmi all
```

---

## 7. 常见问题排错

### 7.1 端口冲突（3000 或 8642 被占用）

**症状：** `docker compose up` 报错 `bind: address already in use`

**解决：** 修改 `docker-compose.yml` 中的端口映射：

```yaml
services:
  open-webui:
    ports:
      - "127.0.0.1:3002:8080"   # 将主机端口从 3000 改为 3002，避开 onboarding 的 3001
  
  hermes:
    ports:
      - "8643:8642"   # 将主机端口从 8642 改为 8643
```

修改后重新启动：

```bash
docker compose down
docker compose up -d
```

同时记得在 `.env` 中同步修改对应端口变量。

### 7.2 Docker daemon 未启动

**macOS：**

```bash
open -a Docker
```

或点击 Launchpad 中的 Docker Desktop 图标启动，等待鲸鱼图标状态变为绿色。

**Linux：**

```bash
sudo systemctl start docker
sudo systemctl enable docker   # 设置为开机自启
```

### 7.3 健康检查失败 / 服务启动异常

**查看 Hermes 日志：**

```bash
docker compose logs hermes          # 全部日志
docker compose logs hermes -f       # 实时跟踪
docker compose logs hermes --tail 50 # 最近 50 行
```

**查看所有服务日志：**

```bash
docker compose logs
```

常见原因：
- 内存不足：确保系统可用内存 ≥ 4GB
- 模型下载失败：检查网络连接，或手动执行 `docker compose pull`
- 配置错误：检查 `.env` 文件格式是否正确

### 7.4 .env 修改后未生效

Docker Compose 在启动时会读取 `.env`，但**运行中的容器不会自动重新加载**。

**正确操作：**

```bash
# 先停止服务
docker compose down

# 再重新启动（会重新读取 .env）
docker compose up -d
```

**不要**使用 `docker compose restart`，它不会重新加载环境变量文件。

### 7.5 其他问题

如果以上方法无法解决，请收集以下信息提交 Issue：

```bash
docker compose version
docker --version
uname -a
docker compose ps
docker compose logs --tail 100 > opendeepseek-logs.txt
```

---

**安装完成！** 访问 http://localhost:3000 开始体验本地 Agentic AI。
