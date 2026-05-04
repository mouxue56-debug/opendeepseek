# 出错怎么办（小白也能看懂）

> 部署过程或日常使用碰到问题？不用慌，对照下面的"症状"找答案。
> 每个问题用**症状**（你看到什么）→ **原因**（大白话）→ **解决**（一步一步）的格式。

## 怎么用这份文档

1. Ctrl+F（Windows）/ Cmd+F（Mac）搜索关键词
2. 找到对应症状
3. 按解决步骤一步步操作
4. 还是不行？跳到末尾"实在搞不定怎么办"

---

## 部署阶段（跑 ./setup.sh 时）

### ❌ 症状：跑 ./setup.sh 报 "permission denied"

**原因**：脚本没有执行权限（电脑不让它跑）

**解决**：
```bash
chmod +x setup.sh
```
👆 这行命令是给脚本开绿灯，让系统允许运行它

```bash
./setup.sh
```
👆 重新运行安装脚本

### ❌ 症状："command not found: docker" 或 "Docker daemon is not running"

**原因**：Docker 没装 / Docker 装了但没启动

**解决**（按你的系统）：

**Mac**：
1. 去 https://www.docker.com/products/docker-desktop/ 下载 Docker Desktop
2. 安装后打开 Docker.app（屏幕下方任务栏会出现一只小鲸鱼图标）
3. 等鲸鱼图标变成稳定不动（不再上下跳动），说明启动完成，再跑 `./setup.sh`

**Windows**：
1. 去 https://www.docker.com/products/docker-desktop/ 下载 Docker Desktop
2. 安装时勾选"Use WSL 2 instead of Hyper-V"（推荐），装完后重启电脑
3. 重启后打开 Docker Desktop，等它左下角显示绿色的"Engine running"
4. 再跑 `./setup.sh`

**Linux**：
```bash
curl -fsSL https://get.docker.com | sh
```
👆 这行命令是自动下载并安装 Docker

```bash
sudo systemctl start docker
```
👆 这行命令是把 Docker 服务启动起来

```bash
sudo systemctl enable docker
```
👆 这行命令是让 Docker 开机自启，下次重启电脑不用手动开

### ❌ 症状："Cannot connect to the Docker daemon"

**原因**：同上，Docker 没启动，或者你当前用户没有操作 Docker 的权限

**解决**：
先确认 Docker Desktop 已经打开并且是绿色运行状态。如果是 Linux 用户，加上 sudo 试试：
```bash
sudo ./setup.sh
```
👆 用管理员身份运行脚本。如果成功了，说明是权限问题，需要把当前用户加到 docker 组里：
```bash
sudo usermod -aG docker $USER
```
👆 这行命令是把你自己加入 docker 权限组。执行完需要退出电脑账号重新登录一次才会生效。

### ❌ 症状：拉镜像太慢 / "manifest for ... not found"

**原因**：你在中国大陆，访问 Docker Hub 官方仓库网速太慢或者连不上

**解决**：配镜像加速（换国内源）。详细见 docs/CHINA-NETWORK.md
快速版：
**Mac/Windows**：打开 Docker Desktop → 点右上角齿轮(Settings) → 点 Docker Engine → 把下面这段加到大括号 `{}` 里面：
```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://hub-mirror.c.163.com"
  ]
}
```
👆 这段配置是让 Docker 去国内镜像站下载，速度会快很多。改完点 "Apply & Restart" 等它重启完。

**Linux**：
```bash
sudo nano /etc/docker/daemon.json
```
👆 这行命令是编辑 Docker 的配置文件。把上面那段带 registry-mirrors 的 JSON 内容粘进去，按 `Ctrl+O` 保存，按 `回车` 确认，按 `Ctrl+X` 退出。

```bash
sudo systemctl restart docker
```
👆 这行命令是重启 Docker 让配置生效

### ❌ 症状："port 3000 already in use" / "bind: address already in use"

**原因**：你电脑上已经有别的程序占用了 3000 或 8642 端口（端口就像是程序的门牌号，一个门牌号只能给一个程序用）

**解决**：
方案 A（关掉占用的程序）：
**Mac/Linux**：
```bash
lsof -i :3000
```
👆 这行命令是查看谁占用了 3000 端口。看输出的最后一列（COMMAND），那就是程序名。去正常关掉那个程序，或者在活动监视器/系统监视器里强制结束它。

**Windows**：
打开 CMD 命令行（不是 Docker 终端），输入：
```bash
netstat -ano | findstr :3000
```
👆 这行命令是查看占用 3000 端口的进程 PID（一串数字）。记住最后那列数字，然后打开任务管理器 → 详细信息 → 找到那个数字对应的进程 → 右键结束任务。

方案 B（让 OpenDeepSeek 用别的端口）：
如果找不到或者不想关那个程序，就改门牌号：
```bash
nano docker-compose.yml
```
👆 这行命令是打开配置文件。找到写着 `3000:3000` 的地方，把前面的 3000 改成 3001（变成 `3001:3000`），保存退出。以后访问就用 `http://localhost:3001`。

### ❌ 症状：API key 输错了

**原因**：复制粘贴时少了字符 / 多了空格 / 填错了别人的 key

**解决**：
1. 重新去 https://platform.deepseek.com/api_keys 复制你的 key
2. ```bash
   nano .env
   ```
   👆 这行命令是打开环境变量配置文件
3. 找到 `DEEPSEEK_API_KEY=` 这行，把等号后面的内容删干净，重新粘贴。确保没有多余空格，也没有前后的引号
4. 按 `Ctrl+O` 保存，按 `回车` 确认，按 `Ctrl+X` 退出
5. ```bash
   docker compose down && docker compose up -d
   ```
   👆 这行命令是先停掉旧服务，再用新配置启动（一定要执行这步，否则改了不生效）

---

## 启动后（容器启动了但用不了）

### ❌ 症状：浏览器打开 http://localhost:3000 显示"无法访问"

**原因**：服务还没完全起来 / 起了但崩溃退出了

**解决**：
```bash
docker compose ps
```
👆 这行命令是看各个容器（可以理解为组成软件的小零件）的状态
- 如果看到都是 `Up healthy` → 服务正常，只是还在加载，等 30 秒再刷新网页试试
- 如果看到有 `Exited` → 说明某个零件崩了。继续输入：
  ```bash
  docker compose logs
  ```
  👆 这行命令是看报错日志，找找里面有没有上面提到的"端口占用"或"API key"错误，对症下药

### ❌ 症状：页面打开了但白屏一片

**原因**：网页的代码加载慢 / 浏览器缓存了旧的错误页面

**解决**：
1. 强制刷新页面：按 `Ctrl+Shift+R`（Windows）/ `Cmd+Shift+R`（Mac）
2. 还不行 → 试试浏览器的"无痕模式"或"隐私模式"打开 http://localhost:3000
3. 还不行 → 刚启动时编译需要时间，等 1 分钟再刷新（特别是第一次跑的时候）

### ❌ 症状：发了消息没反应 / 转圈很久

**原因**：DeepSeek API 调用失败（key 错 / 余额不足 / 网络连不上 DeepSeek 服务器）

**解决**：
```bash
docker compose logs hermes --tail 30
```
👆 这行命令是看 AI 对话核心组件的最近 30 行日志，看输出里有没有这几句话：
- `401 Unauthorized` → API key 错了，按上面"API key 输错了"的步骤改
- `429 Too Many Requests` → 发消息太频繁被限流了，过 1 分钟再发
- `insufficient balance` → DeepSeek 账户没钱了，去 platform.deepseek.com 充值
- `connection timeout` → 网络连不上 DeepSeek，国内用户请看 docs/CHINA-NETWORK.md 配置代理

### ❌ 症状：让 AI 生成网站/写文件一直失败，日志里有 `Read-only file system: '/opt/data/SOUL.md'`

**原因**：Hermes Agent 运行时会确保 `/opt/data/SOUL.md` 存在并可写。如果 docker-compose 把 `hermes/SOUL.md` 挂成只读（`:ro`），所有需要进入 Hermes 的真任务都会 500，包括生成网站、读写 `/host`、图片任务、提醒和记忆。

**解决**：
```bash
docker compose logs hermes --tail 80
```
如果看到 `Read-only file system: '/opt/data/SOUL.md'`，确认 `docker-compose.yml` 里这一行是 `:rw`：
```yaml
- ./hermes/SOUL.md:/opt/data/SOUL.md:rw
```
然后重建 Hermes：
```bash
docker compose up -d --force-recreate hermes hermes-bridge
```
最后跑：
```bash
bash scripts/smoke-test.sh
```
只要第 9 项显示 Smart Bridge 已把任务路由到 Hermes，并实际写入 `/host` 文件，生成网站能力就恢复了。

### ❌ 症状：AI 说文件保存到了 `/host/...`，但我在电脑上找不到

**原因**：`/host` 是 Docker 容器里的路径，不是 macOS Finder 里的真实路径。默认一键安装会把你的用户目录挂到容器的 `/host`，所以：

```text
/host/OpenDeepSeek-Outputs/site/index.html
```

通常对应：

```text
/Users/你的用户名/OpenDeepSeek-Outputs/site/index.html
```

**解决**：

1. 先看 `.env` 里的 `HERMES_HOST_DIR`：

```bash
grep '^HERMES_HOST_DIR=' .env
```

2. 把 `/host` 替换成这个值。例如 `HERMES_HOST_DIR=/Users/lauralyu`，那么 `/host/OpenDeepSeek-Outputs/a.html` 就是 `/Users/lauralyu/OpenDeepSeek-Outputs/a.html`。
3. 新版 Smart Bridge 会自动在 Hermes 回复后追加“本机可找路径”和 `file://` 打开地址。如果没有出现，重启 bridge：

```bash
docker compose up -d --build hermes-bridge
```

### ❌ 症状：让 AI 做很长的网站/PPT，最后空回复或说完成但文件不对

**原因**：这通常不是 OpenWebUI 页面坏了，而是长 Agent 任务在 Hermes 内部被截断：常见日志包括 `Response truncated`、`Truncated tool call`、`Unknown tool 'web_search'`、`Iteration budget exhausted`。

**解决**：

```bash
docker compose logs hermes --tail 120
docker compose logs hermes-bridge --tail 80
```

确认 `.env` 里有这些默认值：

```env
HERMES_AGENT_MAX_TOKENS=32768
HERMES_AGENT_STREAM=false
HERMES_PROGRESS_STREAM=true
OPDS_HOST_DISPLAY_PREFIX=/Users/你的用户名
```

然后重建 bridge：

```bash
docker compose up -d --build hermes-bridge
```

新版会做三件事：提高 Hermes 任务输出上限、让长 Agent 任务先完整执行再回传、要求 Hermes 在说“已保存”前验证文件存在且大小大于 0。特别复杂的网页/PPT，建议让它先生成大纲，再说“按这个大纲生成 HTML/PPT 文件”，成功率更高。

### ❌ 症状：上传 PDF 后 AI 说"我看不到内容"

**原因**：知识库还没整理完文档 / 文档是扫描图片（里面的字没法直接读）

**解决**：
1. 上传后等 2-3 分钟，系统需要把文档变成 AI 能懂的格式（向量化），期间 AI 读不到是正常的
2. 还不行 → 你的文档可能是"图片型 PDF"（比如用扫描仪扫出来的，文字其实是图片）。这种文档需要 OCR（把图片里的字抠出来变成文本）才能读。目前系统暂不支持自动 OCR，请先用在线工具把 PDF 转成文字版再上传
3. 确认正常上传：打开管理员后台（网址后面加 /admin） → 点知识库 → 看看文档状态是不是"完成"

### ❌ 症状：联网搜索不工作

**原因**：联网搜索是可选功能，默认没开启（没启动对应的搜索组件）

**解决**：
```bash
docker compose --profile full up -d
```
👆 这行命令是开启完整模式运行，把搜索组件一起拉起来。运行后等 1 分钟再试

### ❌ 症状：让 AI 跑代码报错

**原因**：系统默认用浏览器内的环境跑代码（Pyodide），不是所有 Python 库都装了

**解决**：常用的 numpy、pandas、matplotlib 都自带；如果你用了冷门库（比如 requests、scipy），默认环境跑不了。需要切到 Jupyter 模式（高级配置，参考 docs/ADVANCED.md），或者让 AI 只输出代码，你自己复制到本地 Python 环境跑。

---

## 升级/卸载

### ❌ 症状：升级后服务起不来

**原因**：新版本配置文件变了，或者下载新版不完整

**解决**：
```bash
./scripts/update.sh
```
👆 这行命令是用自带的更新脚本升级，它会自动备份并处理配置。如果升级失败，它会自动把版本退回去（回退）

如果脚本也报错，手动回退：
```bash
git pull
docker compose down
docker compose up -d
```
👆 这三行是拉最新代码、停服务、重启

### ❌ 症状：想完全删除（包括数据）

**解决**：
```bash
docker compose down -v
```
👆 这行命令是停止并删除容器，`-v` 的意思是把存数据的"数据卷"也一起删掉

```bash
cd .. && rm -rf opendeepseek
```
👆 这行命令是退出文件夹并彻底删除整个项目目录

⚠️ **警告**：数据删了就彻底没了，不可恢复（除非你之前用 `./scripts/backup.sh` 备份过）

---

## 平台特殊问题

### ❌ Windows WSL2 用户：找不到 localhost

**原因**：WSL2（Windows 里的 Linux 子系统）和 Windows 主机有网络隔离，有时候 localhost 没法互通

**解决**：
1. 在 WSL 终端里跑：
   ```bash
   hostname -I
   ```
   👆 这行命令是获取 WSL 的内部 IP 地址（输出类似 `172.x.x.x`）
2. 打开 Windows 上的浏览器，地址栏输入 `http://<刚才那个IP>:3000` 访问

### ❌ macOS：双击 setup.sh 提示"开发者无法验证" / 损坏

**原因**：macOS 安全机制拦截了从网上下载的脚本

**解决**：
不要双击，用终端跑：
```bash
cd ~/opendeepseek
./setup.sh
```
👆 这两行是进入项目目录并运行脚本

如果终端里还报"无法验证开发者"：
```bash
xattr -d com.apple.quarantine setup.sh
```
👆 这行命令是解除 macOS 对这个脚本的隔离标记。输入电脑开机密码（输入时看不到字符，正常输完回车即可），然后再跑 `./setup.sh`

### ❌ .env 文件意外删了

**原因**：手动清理文件时不小心删了，导致启动读不到配置

**解决**：
```bash
cp .env.example .env
```
👆 这行命令是从模板复制一个新的配置文件出来

```bash
nano .env
```
👆 这行命令是编辑配置文件，把你正确的 `DEEPSEEK_API_KEY` 填进去，保存退出

```bash
./setup.sh
```
👆 重新跑安装脚本，当它问你要不要重新配置时，选 `N`（否），脚本会直接读取你刚填好的 .env 文件

---

## 实在搞不定怎么办

1. **导出完整日志给懂行的朋友看**：
   ```bash
   docker compose logs --tail 100 > /tmp/odp-logs.txt
   ```
   👆 这行命令是把最近 100 行日志保存到 `/tmp/odp-logs.txt` 文件里。你可以用记事本打开这个文件，把内容发给帮你排查问题的人

2. **重置一切（核选项，慎用）**：
   ```bash
   docker compose down -v
   ```
   👆 这行命令是停掉服务并删掉所有数据

   ```bash
   rm .env
   ```
   👆 这行命令是删掉配置文件

   ```bash
   ./setup.sh --web
   ```
   👆 这行命令是从头开始安装配置
   
   ⚠️ 警告：这相当于恢复出厂设置，历史聊天和上传文件全没了

3. **去 GitHub 提 Issue（发求助帖）**：
   打开 https://github.com/mouxue56-debug/opendeepseek/issues
   点 "New Issue"，把下面两个命令的输出结果贴进去，方便作者诊断：
   ```bash
   docker compose ps
   ```
   👆 贴出容器运行状态
   
   ```bash
   docker compose logs --tail 50
   ```
   👆 贴出最近报错日志

4. **国内社群**（如有）：QQ 群 / 微信群（待建，关注项目主页通知）
