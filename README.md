# OpenDeepSeek 项目 — 最终可执行方案

> **项目状态**：MVP 开发启动 | **时间**：2026-04-27 | **决策**：Go with Modifications

---

## 一、项目概述

**OpenDeepSeek** = DeepSeek API + Open WebUI + Hermes Agent

**定位**："普通人的一键 AI Agent" — 不写代码、不配环境、5 分钟可用

**核心差异化**：
1. **极简部署**：一条命令启动，零配置接 API
2. **真 Agent 能力**：开箱即用，非角色扮演
3. **极致性价比**：DeepSeek V3 价格仅为 GPT-4o 的 1/9
4. **中文优先**：中文体验最佳

---

## 二、技术架构

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   用户浏览器     │────▶│   Open WebUI    │────▶│  Hermes Agent   │
│  (手机/电脑)     │     │   (前端界面)     │     │  (Agent 引擎)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │                        │
                              ▼                        ▼
                        ┌─────────────────┐     ┌─────────────────┐
                        │   持久化数据     │     │   DeepSeek API  │
                        │   (Docker卷)    │     │  (LLM 后端)     │
                        └─────────────────┘     └─────────────────┘
```

---

## 三、MVP 功能清单（P0）

| # | 功能 | 状态 | 工作量 |
|---|------|------|--------|
| 1 | 聊天界面 + DeepSeek API 接入 | 🟡 待实现 | 低 |
| 2 | 一键部署（Docker Compose） | 🟡 待实现 | 低 |
| 3 | Tool Calling / Function Calling | 🟡 待实现 | 低 |
| 4 | 内置基础工具（搜索、文件读写） | 🟡 待实现 | 中 |
| 5 | API Key 配置向导 | 🟡 待实现 | 低 |

---

## 四、Docker Compose 配置

```yaml
version: '3.8'

services:
  hermes-agent:
    image: nousresearch/hermes-agent:latest
    container_name: opendeepseek-hermes
    ports:
      - "8642:8642"
    environment:
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
      - HERMES_MODEL=deepseek-chat
      - API_SERVER_ENABLED=true
      - API_SERVER_KEY=${HERMES_API_KEY:-opendeepseek-secret}
      - API_SERVER_PORT=8642
      - API_SERVER_HOST=0.0.0.0
    volumes:
      - hermes-data:/root/.hermes
      - ./skills:/root/.hermes/skills:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8642/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: opendeepseek-webui
    ports:
      - "8080:8080"
    environment:
      - OPENAI_API_BASE_URL=http://hermes-agent:8642/v1
      - OPENAI_API_KEY=${HERMES_API_KEY:-opendeepseek-secret}
      - WEBUI_NAME=OpenDeepSeek
      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY:-opendeepseek-webui-secret}
    volumes:
      - open-webui-data:/app/backend/data
    depends_on:
      - hermes-agent
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"

volumes:
  hermes-data:
  open-webui-data:

networks:
  default:
    name: opendeepseek-network
```

---

## 五、Setup.sh 一键安装脚本

```bash
#!/bin/bash
set -e

# OpenDeepSeek 一键安装脚本
# 支持：macOS / Linux / Windows (WSL2)

PROJECT_NAME="OpenDeepSeek"
REQUIRED_DOCKER_VERSION="20.10.0"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
   ____                   _____             _     _
  / __ \                 |  __ \           | |   | |
 | |  | |_ __   ___ _ __| |  | | ___  __ _| | __| |
 | |  | | '_ \ / _ \ '__| |  | |/ _ \/ _` | |/ _` |
 | |__| | |_) |  __/ |  | |__| |  __/ (_| | | (_| |
  \____/| .__/ \___|_|  |_____/ \___|\__,_|_|\__,_|
        | |
        |_|
EOF
    echo -e "${NC}"
    echo -e "${GREEN}一键部署的本地 Agentic ChatGPT${NC}"
    echo -e "${YELLOW}版本：MVP v0.1.0 | 2026-04-27${NC}"
    echo ""
}

# 检查 Docker
check_docker() {
    echo -e "${BLUE}[1/5] 检查 Docker 环境...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker 未安装${NC}"
        echo -e "${YELLOW}请安装 Docker Desktop：https://www.docker.com/products/docker-desktop${NC}"
        
        # 自动安装提示
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "${YELLOW}macOS 用户：brew install --cask docker${NC}"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo -e "${YELLOW}Linux 用户：curl -fsSL https://get.docker.com | sh${NC}"
        fi
        
        exit 1
    fi
    
    if ! docker compose version &> /dev/null && ! docker-compose --version &> /dev/null; then
        echo -e "${RED}❌ Docker Compose 未安装${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Docker 环境正常${NC}"
}

# 配置 API Key
setup_api_key() {
    echo -e "${BLUE}[2/5] 配置 DeepSeek API Key...${NC}"
    echo -e "${YELLOW}获取 API Key：https://platform.deepseek.com/api_keys${NC}"
    
    if [ -f .env ] && grep -q "DEEPSEEK_API_KEY" .env; then
        echo -e "${GREEN}✅ 检测到已有 .env 文件${NC}"
        read -p "是否重新配置？(y/N): " reconfig
        if [[ ! $reconfig =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    read -p "请输入 DeepSeek API Key: " api_key
    
    if [ -z "$api_key" ]; then
        echo -e "${RED}❌ API Key 不能为空${NC}"
        exit 1
    fi
    
    # 生成随机密钥
    hermes_key=$(openssl rand -hex 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 64)
    webui_key=$(openssl rand -hex 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 64)
    
    cat > .env << EOF
# OpenDeepSeek 环境配置
# 生成时间：$(date)

# DeepSeek API（必需）
DEEPSEEK_API_KEY=${api_key}
HERMES_MODEL=deepseek-chat

# Hermes API Server（自动生成）
HERMES_API_KEY=${hermes_key}

# Open WebUI（自动生成）
WEBUI_SECRET_KEY=${webui_key}

# 可选：Tailscale 主机名（用于手机远程访问）
# TAILSCALE_HOSTNAME=opendeepseek
EOF
    
    echo -e "${GREEN}✅ .env 文件已创建${NC}"
    echo -e "${YELLOW}⚠️  .env 文件包含敏感信息，请勿提交到 Git！${NC}"
}

# 预加载 Skills
setup_skills() {
    echo -e "${BLUE}[3/5] 预加载编程 Skills...${NC}"
    
    mkdir -p skills
    
    # 创建基础 skill 集合
    cat > skills/README.md << 'EOF'
# OpenDeepSeek 预加载 Skills

## 已包含 Skills

### 编程开发
- `code-assistant`：通用编程助手
- `git-workflow`：Git 操作工作流
- `docker-helper`：Docker 容器管理

### 系统工具
- `file-operations`：文件读写操作
- `web-search`：网络搜索
- `system-info`：系统信息查询

## 自定义 Skills

将自定义 skill 放入对应目录，Hermes Agent 启动时自动加载。

格式参考：https://agentskills.io/
EOF
    
    echo -e "${GREEN}✅ Skills 目录已创建${NC}"
}

# 启动服务
start_services() {
    echo -e "${BLUE}[4/5] 启动服务...${NC}"
    
    docker compose up -d
    
    echo -e "${GREEN}✅ 服务已启动${NC}"
    echo ""
    echo -e "${YELLOW}等待服务就绪...${NC}"
    
    # 等待健康检查
    for i in {1..30}; do
        if curl -s http://localhost:8642/health > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Hermes Agent 已就绪${NC}"
            break
        fi
        sleep 2
        echo -n "."
    done
    
    echo ""
}

# 显示访问信息
show_access_info() {
    echo -e "${BLUE}[5/5] 访问信息${NC}"
    echo ""
    echo -e "${GREEN}🎉 OpenDeepSeek 部署完成！${NC}"
    echo ""
    echo -e "${YELLOW}本地访问：${NC}"
    echo -e "  Web UI：${GREEN}http://localhost:8080${NC}"
    echo -e "  Hermes API：${GREEN}http://localhost:8642${NC}"
    echo ""
    
    # 检测 Tailscale
    if command -v tailscale &> /dev/null; then
        tailscale_ip=$(tailscale ip -4 2>/dev/null || echo "")
        if [ -n "$tailscale_ip" ]; then
            echo -e "${YELLOW}Tailscale 远程访问：${NC}"
            echo -e "  Web UI：${GREEN}http://${tailscale_ip}:8080${NC}"
            echo -e "  手机浏览器访问上述地址即可${NC}"
            echo ""
        fi
    fi
    
    echo -e "${YELLOW}默认登录：${NC}"
    echo -e "  首次访问需要注册管理员账号${NC}"
    echo ""
    
    echo -e "${YELLOW}常用命令：${NC}"
    echo -e "  查看日志：${GREEN}docker compose logs -f${NC}"
    echo -e "  停止服务：${GREEN}docker compose down${NC}"
    echo -e "  重启服务：${GREEN}docker compose restart${NC}"
    echo ""
    
    echo -e "${YELLOW}文档：https://github.com/yourusername/opendeepseek${NC}"
}

# 主流程
main() {
    print_banner
    check_docker
    setup_api_key
    setup_skills
    start_services
    show_access_info
}

main "$@"
```

---

## 六、项目文件结构

```
opendeepseek/
├── docker-compose.yml          # Docker Compose 配置
├── setup.sh                    # 一键安装脚本
├── .env.example                # 环境变量模板
├── .gitignore                  # Git 忽略规则
├── skills/                     # 预加载 Skills
│   ├── README.md
│   ├── code-assistant/
│   ├── git-workflow/
│   └── docker-helper/
├── docs/                       # 文档
│   ├── README.md
│   ├── INSTALL.md
│   ├── FAQ.md
│   └── TAILSCALE.md
└── scripts/                    # 辅助脚本
    ├── backup.sh
    └── update.sh
```

---

## 七、风险缓解措施

| 风险 | 缓解措施 | 负责人 |
|------|----------|--------|
| 上游 Issue #7895 不修复 | 跟踪上游进度，必要时 Fork 修复 | 待分配 |
| DeepSeek API 不稳定 | 保留 OpenAI API fallback | 待分配 |
| 用户期望过高 | 诚实文档化限制，提供演示模式 | 待分配 |

---

## 八、下一步行动

### 立即执行（本周）
- [ ] 创建 GitHub 仓库
- [ ] 编写 docker-compose.yml
- [ ] 编写 setup.sh 脚本
- [ ] 测试本地部署流程

### 短期目标（2周内）
- [ ] 完成 MVP 功能开发
- [ ] 编写完整文档
- [ ] 邀请 5-10 位测试用户

### 中期目标（1个月内）
- [ ] 发布 v0.1.0 开发者预览版
- [ ] 收集反馈并迭代
- [ ] 建立社区（Discord/微信群）

---

## 九、资源需求

| 资源 | 需求 | 状态 |
|------|------|------|
| DeepSeek API Key | 开发测试用 | 需申请 |
| Docker Hub 账号 | 发布镜像 | 可选 |
| GitHub 仓库 | 代码托管 | 待创建 |
| 域名（可选） | 文档站点 | 待购买 |

---

## 十、联系方式

- **项目仓库**：https://github.com/yourusername/opendeepseek
- **问题反馈**：GitHub Issues
- **讨论交流**：Discord 服务器（待创建）

---

> **决策记录**：2026-04-27 圆桌讨论通过，结论 Go with Modifications
> **核心依据**：技术可行、市场空白、差异化足够、风险可控
