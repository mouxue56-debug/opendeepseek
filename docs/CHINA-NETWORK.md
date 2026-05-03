# 中国网络环境部署指南

> 本文档面向在中国大陆网络环境下部署 OpenDeepSeek 的用户。项目默认架构（Open WebUI 直连 DeepSeek V4）在国内可直接运行：DeepSeek API 国内 CDN 节点稳定访问，**无需翻墙**。仅 Docker 镜像下载和可选的 SearXNG 联网搜索可能需要镜像加速。

---

## 1. DeepSeek API 国内可用性 ✅

DeepSeek API 在中国大陆**无需翻墙**即可直接访问：

- 官方端点：`https://api.deepseek.com`
- 国内有 CDN 节点，延迟正常
- 注册、充值、调用均无障碍

这是 OpenDeepSeek 项目能在国内顺利运行的核心前提。

---

## 2. Docker 镜像加速

国内直接拉取 Docker Hub 镜像速度较慢，建议配置镜像加速。

### 2.1 推荐镜像源

| 镜像源 | 地址 | 说明 |
|--------|------|------|
| DaoCloud | `https://docker.m.daocloud.io` | 免登录，稳定 |
| 网易云 | `https://hub-mirror.c.163.com` | 免登录 |
| 阿里云 | `https://<your-id>.mirror.aliyuncs.com` | 需登录阿里云获取专属地址 |

### 2.2 macOS 配置

**Docker Desktop → Settings → Docker Engine**，编辑 JSON：

```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com"
  ]
}
```

点击 **Apply & Restart**。

### 2.3 Linux 配置

创建或编辑 `/etc/docker/daemon.json`：

```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com"
  ]
}
```

然后重启 Docker：

```bash
sudo systemctl restart docker
```

---

## 3. 搜索服务：避免与推荐

### ❌ 避免使用（国内访问受限）

- **OpenRouter** — 境外聚合服务，国内访问慢且不稳定
- **Tavily Search** — 境外搜索 API，国内网络受限
- **Brave Search** — 部分节点国内不可达

### ✅ 推荐使用

- **SearXNG（自部署）** — 推荐主用。可聚合 Google、Bing、DuckDuckGo 等结果，部署在本地或国内服务器后完全可控
- **DuckDuckGo** — 国内时通时不通，可作为备用
- **Bing 中国版** — 搜索质量一般但连接稳定，兜底方案

> OpenDeepSeek 的「中文优化模式」默认将搜索后端切换为 SearXNG，并关闭 OpenRouter fallback。

---

## 4. setup.sh 中文优化模式详解

运行 `./setup.sh` 时，若选择启用中文优化模式，脚本会自动完成以下调整：

| 调整项 | 具体行为 |
|--------|----------|
| SearXNG 启用 | 执行 `docker compose --profile full up -d`，启动内置 SearXNG 容器 |
| 搜索后端切换 | 将默认搜索服务配置为 SearXNG（替代 Tavily/Brave） |
| 关闭 OpenRouter | 禁用 OpenRouter fallback，避免境外服务超时 |
| 区域设置 | 设置 `zh-CN` locale，优化中文界面与日期格式 |

**一句话总结**：让所有外部依赖都走国内可达节点，确保部署和日常使用不依赖翻墙。

---

## 5. 已有梯子（VPN）的用户

如果你已有稳定的翻墙环境，可以选择：

- **禁用中文优化模式** — 体验更全面的搜索源（Tavily、Brave、OpenRouter 均可正常使用）
- setup.sh 询问「是否启用中文优化模式？」时输入 `no`

> 即使启用中文优化模式，有梯子也不会冲突，只是搜索源范围会受限。

---

## 6. GitHub 克隆加速

国内 `git clone` GitHub 仓库可能较慢，可用镜像加速：

### 单次克隆

```bash
# 方案一：ghproxy
git clone https://ghproxy.com/https://github.com/yourusername/opendeepseek.git

# 方案二：gitclone
git clone https://gitclone.com/github.com/yourusername/opendeepseek.git
```

### 长期配置（推荐）

```bash
git config --global url."https://ghproxy.com/https://github.com/".insteadOf "https://github.com/"
```

配置后，所有 `git clone https://github.com/...` 命令会自动走代理，无需手动改地址。

---

## 7. PaddleOCR 模型下载加速

Open WebUI 使用 **PaddleOCR-vl** 处理中文 PDF 解析，首次使用时会自动下载模型文件。国内直接下载可能较慢。

**解决方案**：通过清华 PyPI 镜像安装 paddlepaddle 依赖：

```bash
docker exec opendeepseek-webui pip install paddlepaddle -i https://pypi.tuna.tsinghua.edu.cn/simple
```

> 此命令在容器内执行，使用清华镜像源加速下载。仅需执行一次，后续复用已下载的模型缓存。

---

## 8. 兜底建议

如果遇到无法解决的网络问题，按以下顺序处理：

1. **临时开启梯子**，完成首次部署和模型下载
2. **部署完成后关闭梯子**，日常运行不需要翻墙（DeepSeek API 国内直连）
3. **仍有问题**，检查 Docker 镜像加速是否生效、SearXNG 容器是否正常运行

---

## 快速检查清单

部署前确认：

- [ ] Docker 镜像加速已配置（daemon.json 或 Docker Desktop 设置）
- [ ] GitHub 克隆已用镜像或已配置 `insteadOf`
- [ ] 运行 `./setup.sh` 时，根据网络环境选择是否启用中文优化模式
- [ ] 部署完成后，验证 DeepSeek API 连通性（WebUI 内发送一条测试消息）
- [ ] 若解析中文 PDF，执行一次 PaddleOCR 加速安装命令

---

> 本文档随项目版本更新，如有网络环境变化或新的镜像源推荐，欢迎提交 PR 补充。
