Config warnings:
- plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel plugin manifest declares wecom without channelConfigs metadata; add openclaw.plugin.json#channelConfigs so config schema and setup surfaces work before runtime loads
- plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel plugin manifest declares wecom without channelConfigs metadata; add openclaw.plugin.json#channelConfigs so config schema and setup surfaces work before runtime loads
│
◇  Config warnings ───────────────────────────────────────────────────────╮
│                                                                         │
│  - plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel     │
│    plugin manifest declares wecom without channelConfigs metadata; add  │
│    openclaw.plugin.json#channelConfigs so config schema and setup       │
│    surfaces work before runtime loads                                   │
│  - plugins.entries.openclaw-wechat: plugin openclaw-wechat: channel     │
│    plugin manifest declares wecom without channelConfigs metadata; add  │
│    openclaw.plugin.json#channelConfigs so config schema and setup       │
│    surfaces work before runtime loads                                   │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────╯
model.run via local
provider: coding-plan-intl
model: qwen3.6-plus
outputs: 1
## 🔴 严重问题
### 1. 硬编码第三方 Git 代理存在供应链劫持风险
- **位置**：Phase 3 `MIRROR_URLS`
- **问题**：`ghproxy.com`、`gitclone.com` 等公共代理非项目官方维护，HTTPS 终端到终端校验被打破。攻击者可篡改仓库内容注入后门或勒索脚本，直接用于生产环境部署违反安全基线。
- **修改**：
  ```diff
  - MIRROR_URLS=(
  -   "https://ghproxy.com/https://github.com/yourusername/opendeepseek.git"
  -   "https://gitclone.com/github.com/yourusername/opendeepseek.git"
  - )
  + # 安全建议：移除硬编码第三方代理。若需国内加速，应指导用户配置系统级代理
  + # 或使用官方认可的加速方案（如 GitHub CLI gh proxy）。
  + MIRROR_URLS=()
  
  # 在 CLONE 逻辑前增加安全提示（如必须使用镜像）：
  + warn "注意：使用第三方镜像可能引入代码篡改风险，生产环境请尽量直连或配置可信企业代理。"
  ```

### 2. 清理逻辑缺乏路径安全边界校验
- **位置**：`_cleanup()` 函数内 `rm -rf "$INSTALL_DIR"`
- **问题**：未校验 `$INSTALL_DIR` 是否为空字符串、根目录 `/` 或包含 `..` 跳转。若因环境变量注入或逻辑缺陷导致路径异常，`rm -rf` 将造成灾难性宿主机数据丢失。
- **修改**：
  ```diff
  _cleanup() {
    if [[ "$CLEANUP_ON_EXIT" -eq 1 && -n "$INSTALL_DIR" && -d "$INSTALL_DIR" ]]; then
  +   # 安全拦截：禁止清理根目录、家目录或相对路径跳转
  +   if [[ "$INSTALL_DIR" == "/" || "$INSTALL_DIR" == "$HOME" || "$INSTALL_DIR" =~ \.\. ]]; then
  +     err "安全检查拦截：拒绝执行危险清理操作 $INSTALL_DIR"
  +     return
  +   fi
      warn "安装中止，清理残留目录: $INSTALL_DIR"
      rm -rf "$INSTALL_DIR"
    fi
  }
  ```

## 🟠 改进建议
### 1. `curl | bash` 管道模式缺乏完整性校验与中断控制
- **位置**：文件头部 Usage 注释
- **问题**：网络波动或中间人攻击会导致脚本下载不完整或执行被篡改命令。一键管道模式无法让用户先审查后执行，不符合企业交付安全规范。
- **修改**：
  ```bash
  # 推荐用户采用“先下载 -> 验签 -> 后执行”的安全链路
  # 1. curl -fsSL https://raw.githubusercontent.com/yourusername/opendeepseek/main/install.sh -o install.sh
  # 2. curl -fsSL https://raw.githubusercontent.com/yourusername/opendeepseek/main/install.sh.sha256 -o install.sh.sha256
  # 3. sha256sum -c install.sh.sha256 && chmod +x install.sh && ./install.sh
  ```

### 2. 使用 `ping` 探测网络连通性冗余且跨平台不一致
- **位置**：Phase 3 `if ping -c 1 -W 3 ... || ping -c 1 -t 3 ...`
- **问题**：不同 OS `ping` 超时参数不一致；现代服务器/WSL 常禁用 ICMP；`ping` 通不代表 `git` 协议通。前置检测增加无谓延迟，应依赖 `git clone` 自身的超时与重试机制。
- **修改**：
  ```diff
  - if ping -c 1 -W 3 github.com &>/dev/null 2>&1 || ping -c 1 -t 3 github.com &>/dev/null 2>&1; then
  -   if _try_clone "$REPO_URL"; then
  -     CLONED=1
  -   fi
  - fi
  
  + # 直接尝试直连，利用 git 原生网络栈，配合 timeout 防阻塞
  + if timeout 15s git ls-remote "$REPO_URL" &>/dev/null; then
  +   if _try_clone "$REPO_URL"; then
  +     CLONED=1
  +   fi
  + fi
  ```

### 3. 更新路径 `git pull origin main` 硬编码分支名
- **位置**：Phase 2 Option 2 `git pull origin main`
- **问题**：部分老旧仓库默认分支仍为 `master`，硬编码 `main` 会导致更新失败。
- **修改**：
  ```bash
  # 动态获取默认分支，或交由 git 自动处理
  BRANCH=$(git config --get init.defaultBranch 2>/dev/null || echo "main")
  if git pull origin "$BRANCH"; then
  ```

## 🟡 风格质量
### 1. `read` 命令未忽略 `IFS` 导致路径首尾空格丢失
- **位置**：Phase 2 `read -rp "  安装到哪里？ [默认: $DEFAULT_DIR]: " INPUT_DIR`
- **问题**：Bash 默认 `read` 会丢弃首尾空格。若用户输入 `~/my project ` 会被截断为 `~/my project`，后续路径解析虽可能成功，但违背最小惊讶原则且易在特殊字符下引发未定义行为。
- **修改**：`IFS= read -rp "  安装到哪里？ [默认: $DEFAULT_DIR]: " INPUT_DIR`

### 2. 冗余的 `cd` 调用
- **位置**：Phase 2 Option 2 成功分支 `cd "$INSTALL_DIR"` 出现两次
- **问题**：逻辑冗余，影响可读性。
- **修改**：删除第二行 `cd "$INSTALL_DIR"`。

### 3. 发布前占位符未替换
- **位置**：全局 `yourusername`
- **问题**：脚本保留示例用户名，直接执行将返回 404，破坏“30秒一键部署”的核心承诺。
- **修改**：全局替换 `yourusername` 为实际 GitHub Organization 或 User 名称，并在 CI/CD 中加入占位符检查步骤（如 `grep -r "yourusername" install.sh && exit 1`）。
