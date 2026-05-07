# OpenDeepSeek CN 产品线路线图

最后更新：2026-05-06
定位：中文优先、国内网络友好、一键安装、真 Agent、漂亮入口。

---

## 1. 核心判断

OpenDeepSeek 的下一阶段必须把“国内可用”单独当成产品线来做。

原因很直接：

- GitHub raw 不稳定。
- GHCR / Docker Hub 镜像可能拉不下来。
- Hugging Face 模型可能下载失败。
- npm / pip / pnpm 默认源可能慢。
- OpenWebUI 原生英文和后台感强，小白用户容易卡住。
- 生成文件只返回 `/host/...` 路径时，小白找不到产物。

如果中国用户第一步就卡死在安装和镜像下载上，后面的 Hermes Agent、DeepSeek V4 Flash、Smart Bridge 再强也没有机会被体验到。

OpenDeepSeek CN 的目标不是换一个下载链接，而是做一层完整的国内分发层、国内网络适配层和中文产品体验层。

---

## 2. 一句话定位

> OpenDeepSeek CN：给中国用户的一键本地 DeepSeek Agent 工作台。

更口语的产品话术：

> 不只是聊天。它能读文件、写报告、生成网页、整理资料、设置提醒，并且国内网络也能装上。

---

## 3. 产品目标

### 3.1 中国用户能装上

必须做到：

- 不依赖 GitHub raw 作为唯一入口。
- 不依赖用户自己配置 Docker 镜像加速器。
- 不依赖首次启动时从 Hugging Face 拉模型。
- 提供 Gitee / GitCode / OSS / COS / 国内容器镜像仓库。
- 提供离线安装包作为兜底。

### 3.2 中国用户看得懂

必须做到：

- 中文 onboarding。
- 中文安装文档。
- 中文网络体检。
- 中文错误提示。
- 中文示例任务。
- 不把 Docker、Bridge、Hermes、endpoint 等技术词暴露给小白，除非用户主动打开高级模式。

### 3.3 中国用户敢用

必须做到：

- 明确说明 Agent 能访问哪些目录。
- 默认只授权安全目录。
- 用户主动勾选后才允许访问桌面、下载、文档等目录。
- 公网模式强制登录。
- 无认证公网暴露时拒绝启动。

### 3.4 中国用户能看到产物

必须做到：

- 生成网页、报告、PPT 后不只返回 `/host/...`。
- 提供本机路径。
- 提供预览按钮。
- 提供“打开文件夹”按钮。
- 做“我的产物”页面。

---

## 4. 国内分发三层保障

### 4.1 第一层：源码镜像

建议分发结构：

| 平台 | 作用 |
|---|---|
| GitHub | 主开发仓库 |
| Gitee | 国内用户首选安装源 |
| GitCode / CNB | 国内备用源 |
| 阿里云 OSS / 腾讯云 COS | Release 包、离线包、manifest |

注意：

- Gitee/GitCode 适合同步 branches、tags、commits。
- Release assets、离线镜像包、压缩包不要只依赖代码镜像平台。
- 大文件和离线包应走 OSS/COS/CDN。

### 4.2 第二层：容器镜像

国内版不应要求用户自己能拉 GHCR 或 Docker Hub。

建议自建并发布：

```text
registry.cn-hangzhou.aliyuncs.com/opendeepseek/open-webui
registry.cn-hangzhou.aliyuncs.com/opendeepseek/hermes
registry.cn-hangzhou.aliyuncs.com/opendeepseek/hermes-bridge
registry.cn-hangzhou.aliyuncs.com/opendeepseek/searxng
registry.cn-hangzhou.aliyuncs.com/opendeepseek/onboarding
```

新增 `docker-compose.cn.yml`：

```yaml
services:
  open-webui:
    image: ${OPDS_IMAGE_REGISTRY:-registry.cn-hangzhou.aliyuncs.com/opendeepseek}/open-webui:${OPENWEBUI_VERSION:-0.9.2-opds-cn}

  hermes:
    image: ${OPDS_IMAGE_REGISTRY:-registry.cn-hangzhou.aliyuncs.com/opendeepseek}/hermes:${HERMES_VERSION:-opds-cn}

  hermes-bridge:
    image: ${OPDS_IMAGE_REGISTRY:-registry.cn-hangzhou.aliyuncs.com/opendeepseek}/hermes-bridge:${OPDS_VERSION:-0.5.0-cn}

  searxng:
    image: ${OPDS_IMAGE_REGISTRY:-registry.cn-hangzhou.aliyuncs.com/opendeepseek}/searxng:${SEARXNG_VERSION:-opds-cn}
```

### 4.3 第三层：离线安装包

必须提供离线包。

建议发行物：

```text
opendeepseek-cn-v0.5.0-macos-arm64.zip
opendeepseek-cn-v0.5.0-macos-amd64.zip
opendeepseek-cn-v0.5.0-windows-amd64.zip
opendeepseek-cn-v0.5.0-linux-amd64.tar.gz
opendeepseek-cn-v0.5.0-linux-arm64.tar.gz
opendeepseek-images-cn-v0.5.0-amd64.tar.zst
opendeepseek-images-cn-v0.5.0-arm64.tar.zst
```

离线包内容：

```text
install-cn.sh
install-cn.ps1
docker-compose.cn.yml
.env.example.cn
OpenDeepSeek.command
OpenDeepSeek.bat
onboarding/
portal/
docs/zh-CN/
checksums.txt
images/
  opendeepseek-images-cn-amd64.tar.zst
```

离线安装逻辑：

```bash
docker --version
zstd -d images/opendeepseek-images-cn-amd64.tar.zst -c | docker load
cp .env.example.cn .env
docker compose -f docker-compose.cn.yml up -d
open http://localhost:3001
```

---

## 5. 中国版安装入口

### 5.1 国际版

继续保留：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mouxue56-debug/opendeepseek/main/install.sh)
```

### 5.2 中国版

新增：

```bash
bash -c "$(curl -fsSL https://gitee.com/luoxueai/opendeepseek/raw/main/install-cn.sh)"
```

Windows PowerShell：

```powershell
irm https://gitee.com/luoxueai/opendeepseek/raw/main/install-cn.ps1 | iex
```

### 5.3 `install-cn.sh` 定位

`install-cn.sh` 不是 `install.sh` 的简单复制，而是智能下载器。

流程：

```text
1. 检测系统：macOS / Linux / Windows WSL
2. 检测 CPU 架构：amd64 / arm64
3. 检测 Docker 是否存在和是否启动
4. 检测网络源：
   - Gitee raw
   - GitCode raw
   - 阿里云 OSS
   - 腾讯云 COS
   - 国内容器镜像仓库
   - api.deepseek.com
5. 选择最快源
6. 下载 release-cn.json
7. 校验 sha256
8. 下载 compose、脚本、onboarding、portal
9. 拉取国内镜像
10. 拉取失败则提示离线包
11. 启动中文 onboarding
```

---

## 6. `release-cn.json`

新增 `release-cn.json`，作为国内安装器的唯一真相源。

示例：

```json
{
  "version": "0.5.0-cn",
  "commit": "xxxxxxx",
  "published_at": "2026-05-06T00:00:00+08:00",
  "sources": {
    "gitee": "https://gitee.com/luoxueai/opendeepseek",
    "gitcode": "https://gitcode.com/mouxue56-debug/opendeepseek",
    "github": "https://github.com/mouxue56-debug/opendeepseek"
  },
  "assets": {
    "macos-arm64": {
      "url": "https://opendeepseek-cn.oss-cn-hangzhou.aliyuncs.com/releases/v0.5.0/opendeepseek-cn-macos-arm64.zip",
      "sha256": "..."
    },
    "windows-amd64": {
      "url": "https://opendeepseek-cn.oss-cn-hangzhou.aliyuncs.com/releases/v0.5.0/opendeepseek-cn-windows-amd64.zip",
      "sha256": "..."
    }
  },
  "images": {
    "registry": "registry.cn-hangzhou.aliyuncs.com/opendeepseek",
    "digest_lock": {
      "open-webui": "sha256:...",
      "hermes": "sha256:...",
      "hermes-bridge": "sha256:...",
      "searxng": "sha256:..."
    }
  }
}
```

要求：

- 所有下载必须校验 sha256。
- 镜像推荐固定 digest。
- 安装器要能在 Gitee/GitCode/OSS 之间自动 fallback。

---

## 7. 国内依赖源默认配置

新增 `.env.example.cn`。

建议默认：

```env
OPDS_REGION=cn

# Python
PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

# Node / npm
NPM_CONFIG_REGISTRY=https://registry.npmmirror.com
PNPM_REGISTRY=https://registry.npmmirror.com

# Open WebUI
DEFAULT_LOCALE=zh-CN
WEBUI_NAME=OpenDeepSeek
DEFAULT_MODELS=opendeepseek-auto
DEFAULT_PINNED_MODELS=opendeepseek-auto,opendeepseek-fast,opendeepseek-agent,opendeepseek-deepwork
ENABLE_COMMUNITY_SHARING=false
ENABLE_VERSION_UPDATE_CHECK=false
ENABLE_EASTER_EGGS=false

# RAG / 中文友好
RAG_EMBEDDING_MODEL=BAAI/bge-small-zh-v1.5
ENABLE_RAG_HYBRID_SEARCH=true

# DeepSeek
DEEPSEEK_API_BASE=https://api.deepseek.com
DEFAULT_MODEL=deepseek-v4-flash
```

注意：

- 在线国内版使用国内镜像和预置中文 embedding。
- 离线版再启用 `OFFLINE_MODE` / `HF_HUB_OFFLINE`。
- 不要一刀切默认离线模式，否则没预置模型时 RAG/文档解析会坏。

---

## 8. DeepSeek API 层

默认只推荐官方 DeepSeek API：

```env
DEEPSEEK_API_BASE=https://api.deepseek.com
DEEPSEEK_API_KEY=sk-xxx
DEFAULT_MODEL=deepseek-v4-flash
```

Bridge 可逐步抽象成：

```env
OPDS_LLM_PROVIDER=deepseek
OPDS_LLM_BASE_URL=${DEEPSEEK_API_BASE}
OPDS_LLM_MODEL=deepseek-v4-flash
```

原则：

- 不把不明第三方转发站写进默认配置。
- 允许高级用户自填 OpenAI-compatible endpoint。
- 默认保护用户 API Key 和数据安全。

---

## 9. 国内搜索策略

当前已有 SearXNG 和 Bridge 搜索快照。国内版需要更明确的搜索 provider 策略。

新增：

```env
OPDS_SEARCH_PROVIDER=auto
```

可选值：

```text
auto
searxng
bocha
bing
jina
baidu-lite
none
```

建议路由：

| 场景 | 优先 |
|---|---|
| 中文实时新闻/资料 | Bocha / Bing / SearXNG 中文源 |
| 网页正文清洗 | Jina |
| 国际论文/英文资料 | Jina / SearXNG global / Bing |
| 搜索不可用 | 明确告诉用户不可用，不编造 |

产品原则：

- OpenWebUI 原生搜索保留。
- Bridge 可提供搜索快照。
- Hermes 可在 Agent 长任务里继续二次搜索。
- 三路搜索能力要能诊断和配置，不要互相打架。

---

## 10. UI 产品路线

### 10.1 不硬改 Open WebUI 品牌

Open WebUI 深度 logo/theme/branding 自定义存在许可证边界。OpenDeepSeek 不应走“硬魔改 Open WebUI”的路线。

更稳的产品结构：

```text
http://localhost:3001  OpenDeepSeek Portal / 引导页 / 控制台
http://localhost:3000  Open WebUI 专业聊天界面
```

用户先看到 OpenDeepSeek Portal，而不是 Open WebUI 后台感界面。

### 10.2 小白模式 + 专业模式

Portal 首页：

```text
OpenDeepSeek
让 DeepSeek 真正操作你的电脑

[开始使用] [导入文件] [查看产物] [设置 API Key]

快速问答     真 Agent 任务     知识库问答
整理桌面     生成网页          设置提醒
```

用户关心的问题要前置：

- 我能不能用？
- 会不会动我的电脑？
- 文件生成在哪？
- 要不要花钱？
- 怎么关？

### 10.3 四个产品化模式

在 Portal/Lite UI 或 OpenWebUI pinned models 里暴露：

```text
opendeepseek-auto       自动模式，默认，自动判断快问答/真任务
opendeepseek-fast       极速问答，强制 DeepSeek V4 Flash
opendeepseek-agent      真 Agent，强制 Hermes 执行文件/网页/提醒
opendeepseek-deepwork   深度任务，DeepSeek V4 Pro + Hermes
```

用户看到的是模式，不是后端技术名。

---

## 11. 产物中心

当前“文件已保存到 `/host/...`”对小白不友好。

目标回复：

```text
✅ 已生成个人主页

预览：
[打开网页]

文件：
[打开本机文件夹]  /Users/lauralyu/OpenDeepSeek-Outputs/site

包含：
- index.html
- style.css
- assets/avatar.png

下一步：
[继续美化] [打包成 zip] [发布到本地预览]
```

### 11.1 Artifact Manifest

新增 artifact manifest：

```json
{
  "task_id": "20260506-abc123",
  "title": "个人主页",
  "type": "website",
  "created_at": "2026-05-06T20:00:00+08:00",
  "local_root": "/Users/lauralyu/OpenDeepSeek-Outputs/site",
  "container_root": "/host/OpenDeepSeek-Outputs/site",
  "files": [
    {
      "path": "index.html",
      "mime": "text/html",
      "preview_url": "http://localhost:8770/artifacts/20260506-abc123/index.html"
    }
  ]
}
```

### 11.2 Portal 产物页

```text
我的产物
- 今天 20:31 个人主页       [预览] [打开文件夹] [删除]
- 今天 19:10 周报.docx      [下载] [打开文件夹]
- 昨天 22:02 桌面整理报告   [查看]
```

这会把 OpenDeepSeek 从工程项目推进成普通用户能理解的产品。

---

## 12. Onboarding 2.0

国内版 onboarding 建议 5 步。

### 第 1 步：欢迎

```text
欢迎使用 OpenDeepSeek

它可以：
✓ 快速回答问题
✓ 读取和整理你的本机文件
✓ 生成网页、报告、PPT
✓ 根据图片做网页/文档
✓ 设置提醒和定时任务
```

### 第 2 步：选择模式

```text
家庭本机模式，推荐
- 只在本机访问
- 不需要登录
- Hermes 可访问你授权的目录

安全演示模式
- 只访问 OpenDeepSeek-Inputs/Outputs
- 适合试用、录视频、分享给别人看

团队/公网模式
- 必须开启登录
- 只暴露 Open WebUI
- Hermes/Bridge 不暴露公网
```

### 第 3 步：填写 DeepSeek API Key

```text
请输入 DeepSeek API Key
[ sk-xxxxxxxxxxxxxxxx ]

不知道怎么获取？
[查看图文教程]

默认模型：deepseek-v4-flash
适合：日常问答、写作、Agent 工具执行
```

### 第 4 步：选择允许访问的本机目录

默认：

```text
[✓] OpenDeepSeek-Inputs
[✓] OpenDeepSeek-Outputs
[ ] 桌面
[ ] 下载
[ ] 文档
[自定义目录]
```

### 第 5 步：开始使用

```text
一切就绪

[打开 OpenDeepSeek]
[运行一次测试任务]
```

测试任务：

```text
请在 OpenDeepSeek-Outputs 里生成一个 hello.txt，写入“你好，OpenDeepSeek”。
```

成功提示：

```text
✅ Agent 文件写入已验证
```

---

## 13. 国内版默认系统提示

`opendeepseek-auto` 的默认提示应更产品化：

```text
你是 OpenDeepSeek，一个中文优先的本地 Agent 助手。

你的默认行为：
1. 普通问答要简洁、快速、中文优先。
2. 如果用户要求读取、整理、创建、修改本机文件，必须走 Agent 执行，不要假装已完成。
3. 如果用户要求生成网页、PPT、报告、脚本等真实产物，必须保存到 OpenDeepSeek-Outputs，并在完成后说明本机路径。
4. 如果用户上传图片，先说明你会结合图片路径和 OCR 信息处理。
5. 如果问题依赖实时信息，要使用搜索工具或明确说明当前无法联网确认。
6. 不要让用户理解 Docker、Hermes、Bridge 等底层概念，除非用户主动问。
```

中国用户高频触发词：

```text
帮我做个网页
生成一个PPT
保存到桌面
放到我的下载里
帮我整理这个文件夹
明天提醒我
每天早上发我早报
把这张图做成页面
帮我写个小程序页面
帮我做个公众号排版
```

---

## 14. OpenWebUI CN 默认化

`docker-compose.cn.yml` 建议设置：

```yaml
environment:
  - DEFAULT_LOCALE=zh-CN
  - WEBUI_NAME=OpenDeepSeek
  - DEFAULT_MODELS=opendeepseek-auto
  - DEFAULT_PINNED_MODELS=opendeepseek-auto,opendeepseek-fast,opendeepseek-agent,opendeepseek-deepwork
  - ENABLE_COMMUNITY_SHARING=false
  - ENABLE_VERSION_UPDATE_CHECK=false
  - ENABLE_EASTER_EGGS=false
  - CORS_ALLOW_ORIGIN=http://localhost:3000;http://127.0.0.1:3000
```

注意 OpenWebUI 有 persistent config 行为：

- 首次启动后部分配置会写入数据库。
- 后续改 `.env` 不一定立刻生效。
- `setup.sh verify` / `doctor-cn` 需要检查实际配置，不只检查 `.env`。

需要提示用户：

```text
检测到 Open WebUI 已保存旧配置。
请选择：
1. 自动修复配置
2. 打开 Admin 设置页面
3. 重置 Open WebUI 配置，不删除聊天记录
```

---

## 15. opds-control

新增 `opds-control` 作为 Portal 和 OpenAPI Tool Server 的控制平面。

建议 API：

```text
GET  /health
GET  /diagnostics
POST /diagnostics/network-cn
GET  /artifacts
GET  /artifacts/{id}
POST /runs/{id}/stop
GET  /runs/{id}/events
GET  /settings
POST /settings/deepseek-key
POST /settings/allowed-folders
POST /search/test
POST /mirror/test
```

### 15.1 网络体检

`/diagnostics/network-cn` 检测：

```text
Gitee 可达性
GitCode 可达性
阿里云 OSS 可达性
腾讯云 COS 可达性
国内容器镜像仓库可达性
DeepSeek API 可达性
SearXNG 可达性
搜索 provider 可用性
PyPI 镜像可用性
npm 镜像可用性
OpenWebUI ↔ Bridge 连接
Bridge ↔ Hermes 连接
Hermes ↔ /host 写入权限
```

用户看到：

```text
网络体检

✅ DeepSeek API 可用
✅ 国内镜像仓库可用
✅ OpenWebUI 已连接 Bridge
✅ Hermes Agent 可写入文件
⚠️ 搜索服务不可用：建议填写 Bocha Key 或切换 Bing
❌ GitHub 不可达：已自动切换到 Gitee
```

---

## 16. 国内公网部署安全模式

安装器必须区分：

```text
本机使用：
无需备案，不开放公网

局域网使用：
只在家里/办公室访问，建议开启登录

公网中国大陆服务器：
需要考虑 ICP 备案、HTTPS、登录、访问控制、日志、安全边界

海外服务器：
无需中国大陆 ICP，但国内访问速度可能不稳定
```

强制安全规则：

```text
如果 BIND_HOST=0.0.0.0 且 WEBUI_AUTH=false：
拒绝启动，除非用户显式设置 OPDS_I_KNOW_THIS_IS_UNSAFE=true
```

团队版默认不要给普通用户开放高风险 Workspace Tools / Functions。

---

## 17. 国内文档结构

新增：

```text
docs/zh-CN/
  00-我应该下载哪个版本.md
  01-mac安装.md
  02-windows安装.md
  03-linux安装.md
  04-国内网络问题.md
  05-离线安装.md
  06-填写DeepSeek-Key.md
  07-文件权限说明.md
  08-生成文件在哪.md
  09-常见错误.md
  10-公网部署和安全.md
```

写法要回答小白真实问题：

- 我是 Mac 用户，怎么装？
- 我是 Windows 用户，怎么装？
- Docker 拉不下来怎么办？
- GitHub 打不开怎么办？
- API Key 怎么填？
- 生成的文件在哪？
- 怎么让它访问桌面？
- 怎么关掉它？
- 会不会乱删我文件？
- 怎么卸载？
- 怎么更新？

---

## 18. 推荐版本规划

### v0.4.2：先合并发布

目标：海外/开发者可用。

- PR 合并 main。
- 当前 Smart Bridge 稳定。
- smoke-test 保持全绿。

### v0.5.0-cn：国内安装可用

目标：中国用户能装上。

- `install-cn.sh`
- `install-cn.ps1`
- `docker-compose.cn.yml`
- `.env.example.cn`
- `release-cn.json`
- Gitee + GitCode 镜像。
- 国内 ACR 镜像。
- OSS/COS release 包。
- 国内网络诊断。
- `docs/zh-CN/` 国内安装说明。

### v0.6.0-cn：国内体验好用

目标：中国小白觉得好用。

- OpenDeepSeek Portal。
- 中文 onboarding 2.0。
- 产物中心。
- 文件夹授权 UI。
- 搜索 provider 自动检测。
- DeepSeek Key 图文引导。
- 模式卡片：自动/极速/真 Agent/深度。

### v0.7.0：产品化

目标：像一个完整产品。

- OpenDeepSeek Lite UI。
- Artifact Manifest。
- 长任务进度/停止/重试。
- Memory Broker。
- 一键更新/回滚。
- Windows 桌面快捷方式。
- macOS DMG。

---

## 19. 计划新增文件

```text
install-cn.sh
install-cn.ps1
docker-compose.cn.yml
.env.example.cn
release-cn.json
scripts/sync-images-cn.sh
scripts/build-offline-bundle.sh
scripts/check-network-cn.sh
docs/zh-CN/00-我应该下载哪个版本.md
docs/zh-CN/01-mac安装.md
docs/zh-CN/02-windows安装.md
docs/zh-CN/03-linux安装.md
docs/zh-CN/04-国内网络问题.md
docs/zh-CN/05-离线安装.md
docs/zh-CN/06-填写DeepSeek-Key.md
docs/zh-CN/07-文件权限说明.md
docs/zh-CN/08-生成文件在哪.md
docs/zh-CN/09-常见错误.md
docs/zh-CN/10-公网部署和安全.md
portal/index.html
portal/assets/
control/server.py
```

## 20. 计划修改文件

```text
README.md
docs/ONE-CLICK.md
docs/CHINA-NETWORK.md
docs/PUBLIC-DEPLOYMENT.md
setup.sh
scripts/verify_config.py
onboarding/index.html
bridge/hermes_image_bridge.py
```

`setup.sh` 新增命令：

```bash
./setup.sh --cn
./setup.sh --cn --offline ./opendeepseek-images-cn-amd64.tar.zst
./setup.sh doctor-cn
./setup.sh switch-mirror aliyun
./setup.sh switch-mirror tencent
```

---

## 21. 实施顺序

### 第一批：低风险文档与脚手架

1. 新增 `docs/OPENDEEPSEEK-CN-ROADMAP.md`。
2. 新增 `docs/zh-CN/` 小白文档骨架。
3. 新增 `release-cn.json` schema 草案。
4. 新增 `.env.example.cn`。
5. 新增 `docker-compose.cn.yml`，先可引用占位镜像 registry。

### 第二批：安装器与网络诊断

1. `install-cn.sh` 智能源检测。
2. `scripts/check-network-cn.sh`。
3. `./setup.sh doctor-cn`。
4. `./setup.sh --cn`。

### 第三批：国内镜像与离线包

1. `scripts/sync-images-cn.sh`。
2. `scripts/build-offline-bundle.sh`。
3. ACR 镜像发布。
4. OSS/COS 离线包发布。
5. checksum 验证。

### 第四批：Portal 与产物中心

1. `portal/` 首页。
2. `control/server.py`。
3. `/diagnostics/network-cn`。
4. `/artifacts`。
5. Artifact Manifest。

### 第五批：OpenDeepSeek Lite

1. 自有轻量聊天 UI。
2. 四模式切换。
3. 原生进度条。
4. 停止/重试。
5. 文件授权 UI。

---

## 22. 当前结论

OpenDeepSeek CN 应该成为项目下一阶段的主线之一。

项目已有的 Smart Bridge、Hermes Agent、OpenWebUI、onboarding、install.sh、setup.sh、smoke-test 基础已经足够，不需要推倒重来。

下一步要补的是：

```text
国内分发层
国内网络诊断
国内容器镜像
离线包
中文 Portal
产物中心
文件授权 UI
小白文档
```

这条路线的核心价值是：

> 不是又一个套壳 DeepSeek，而是中国用户真的能装上、看懂、敢用、能看到文件产物的本地 Agent 平台。
