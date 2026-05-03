# OpenDeepSeek 一键部署完整指南

> 本地运行的 Agentic AI 助手，基于 Open WebUI + Hermes Smart Bridge + Hermes Agent + DeepSeek V4，部署后访问 http://localhost:3000 即可使用。

---

## 30 秒上手（最快路径）

只需一行命令：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

然后按提示走完 3 步：

1. 脚本检查 Docker / Git / curl，缺什么会给出安装命令
2. 选择安装目录，浏览器打开配置向导
3. 输入你的 DeepSeek API Key，等待容器启动
4. 浏览器自动打开 http://localhost:3000，直接开始对话

如果你拿到的是发布 zip 包：解压后在 macOS 上双击 `OpenDeepSeek.command`；其他系统在项目目录执行 `./setup.sh --web`。

---

## 系统要求

| 项目 | 最低要求 |
|---|---|
| 操作系统 | macOS / Linux / Windows WSL2 |
| 容器运行时 | Docker Desktop（没装的话 install.sh 会提示） |
| API Key | DeepSeek API Key（在 [platform.deepseek.com](https://platform.deepseek.com) 注册免费获取） |
| 内存 | 4 GB 及以上 |
| 磁盘 | 10 GB 可用空间 |

---

## 三种安装方式对比

### 方式 A：远程一键（推荐普通用户）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

- 自动检测操作系统
- 自动检测依赖、clone 项目、启动配置向导和服务
- 默认启用家庭模式（无需注册登录，访问即用）

### 方式 B：手动 git clone

适合想看源码或修改配置的用户。

```bash
git clone https://github.com/mouxue56-debug/opendeepseek.git
cd opendeepseek
./setup.sh --web
```

### 方式 C：Docker Compose 直接运行（懂 Docker 的用户）

适合已熟悉 Docker 且想完全自主控制配置的用户。

```bash
git clone https://github.com/mouxue56-debug/opendeepseek.git
cd opendeepseek
cp .env.example .env
# 编辑 .env，填入 DEEPSEEK_API_KEY=your_key_here
docker compose up -d
```

---

## 各平台安装说明

### macOS（Apple Silicon / Intel 均支持）

1. 安装 Docker Desktop：

```bash
brew install --cask docker
```

2. 启动 Docker.app（在 Launchpad 或 Applications 找到并打开）

3. 等待顶栏 Docker 图标稳定后，运行 install.sh：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

### Ubuntu / Debian

1. 安装 Docker：

```bash
curl -fsSL https://get.docker.com | sh
```

2. 将当前用户加入 docker 组（免 sudo 运行 docker）：

```bash
sudo usermod -aG docker $USER && newgrp docker
```

3. 运行 install.sh：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

### CentOS / RHEL / Rocky Linux

1. 安装 Docker 并设置开机自启：

```bash
curl -fsSL https://get.docker.com | sh
sudo systemctl enable --now docker
sudo usermod -aG docker $USER && newgrp docker
```

2. 运行 install.sh：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

### Windows（通过 WSL2）

1. 启用 WSL2：

```powershell
wsl --install
```

2. 安装 Ubuntu 发行版：

```powershell
wsl --install -d Ubuntu-22.04
```

3. 安装 [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)，安装完成后在设置中启用 WSL2 后端（Settings → Resources → WSL Integration，勾选 Ubuntu-22.04）

4. 打开 WSL Ubuntu 终端，运行 install.sh：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

---

## 部署模式选择

### 家庭单用户模式（默认，推荐）

配置项：`WEBUI_AUTH=false`

- 访问 http://localhost:3000 直接进入对话界面，无需注册
- 适合：个人独用、家庭共用、通过 Tailscale 远程访问
- 注意：仅限本地或私网使用。若将 3000 端口直接暴露到公网，任何人都可无限制访问，请务必切换为团队模式

### 团队多用户模式

配置项：`WEBUI_AUTH=true`（在 `.env` 文件中修改）

- 首次访问需注册第一个管理员账号
- 后续用户由管理员邀请或开放注册
- 适合：办公室共享服务器、公网部署、多人协作场景

---

## 常见问题速查

| 问题 | 解决方案 |
|---|---|
| `Cannot connect to Docker daemon` | macOS：启动 Docker.app；Linux：`sudo systemctl start docker` |
| `port 3000 already in use` | 在 `docker-compose.yml` 中将端口改为其他值，例如 `127.0.0.1:3002:8080` |
| `git clone` 速度过慢 | install.sh 自动尝试 ghproxy 镜像；也可手动：`git clone https://ghproxy.com/https://github.com/mouxue56-debug/opendeepseek.git` |
| 拉取 Docker 镜像太慢 | 配置 Docker 镜像加速，详见 [CHINA-NETWORK.md](CHINA-NETWORK.md) |
| 浏览器打开但显示白屏 | 首次启动较慢，等待 30 秒后刷新；或运行 `docker compose logs open-webui` 查看日志 |
| API Key 无效 | 确认 `.env` 中 `DEEPSEEK_API_KEY` 已正确填写且无多余空格，重启服务：`docker compose restart` |

---

## 远程访问（Tailscale）

Tailscale 可让你在家以外的地方安全访问家里运行的 OpenDeepSeek，无需公网 IP，无需端口映射。

1. 安装 Tailscale：

```bash
# macOS
brew install tailscale

# Linux
curl -fsSL https://tailscale.com/install.sh | sh
```

2. 启动并登录：

```bash
sudo tailscale up
```

3. 查看本机 Tailscale IP：

```bash
tailscale ip -4
```

4. 在手机或异地电脑上（已登录同一 Tailscale 账号），浏览器访问：

```
http://<tailscale-ip>:3000
```

---

## 升级

当有新版本发布时，进入项目目录执行以下命令：

```bash
cd opendeepseek
git pull
docker compose pull
docker compose down && docker compose up -d
```

升级过程不会丢失对话历史（数据存储在 Docker volume 中）。

---

## 完全卸载

如果不再使用，以下命令会停止所有服务并删除全部数据（包括对话历史）：

```bash
cd opendeepseek
docker compose down -v
cd .. && rm -rf opendeepseek
```

> 警告：`-v` 参数会同时删除 Docker volume，即所有对话记录和配置数据将永久丢失，请确认后再执行。

---

## 哪些情况不适合用 OpenDeepSeek

- **完全不想装 Docker**：推荐直接使用 [chat.deepseek.com](https://chat.deepseek.com) 网页版，无需任何安装
- **需要将服务裸露到公网且无防护措施**：安全风险极高，至少应开启 `WEBUI_AUTH=true` 并配合反向代理 + HTTPS
- **设备内存低于 4 GB**：容器运行性能不足，体验较差

---

## 下一步

| 目标 | 文档 |
|---|---|
| 遇到问题了 | [FAQ](FAQ.md) |
| 接入微信 / Telegram 等 IM | [IM-BRIDGE](IM-BRIDGE.md) |
| 了解内部架构 | [ARCHITECTURE](ARCHITECTURE.md) |
| 想参与贡献 | [CONTRIBUTING](../CONTRIBUTING.md) |
| 国内网络加速 | [CHINA-NETWORK](CHINA-NETWORK.md) |
