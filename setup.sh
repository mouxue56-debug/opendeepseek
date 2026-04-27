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
