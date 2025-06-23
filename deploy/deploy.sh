#!/bin/bash

# 多Agent日志监控系统 - 一键部署脚本
# 支持本地部署和Docker部署两种方式

set -e

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPLOY_MODE=""
COMPONENTS=""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
多Agent日志监控系统 - 一键部署脚本

用法: $0 [选项]

选项:
  -m, --mode MODE       部署模式: local 或 docker (必需)
  -c, --components COMP 要部署的组件: all, service, agent, frontend (默认: all)
  -h, --help           显示此帮助信息

部署模式:
  local    - 本地部署，使用systemd管理服务
  docker   - Docker容器部署

组件:
  all      - 部署所有组件
  service  - 仅部署Service组件
  agent    - 仅部署Agent组件
  frontend - 仅部署Frontend组件

示例:
  $0 -m local -c all              # 本地部署所有组件
  $0 -m docker -c service,agent   # Docker部署Service和Agent
  $0 -m local -c frontend          # 本地部署Frontend

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                DEPLOY_MODE="$2"
                shift 2
                ;;
            -c|--components)
                COMPONENTS="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 验证参数
    if [[ -z "$DEPLOY_MODE" ]]; then
        log_error "必须指定部署模式 (-m|--mode)"
        show_help
        exit 1
    fi

    if [[ "$DEPLOY_MODE" != "local" && "$DEPLOY_MODE" != "docker" ]]; then
        log_error "无效的部署模式: $DEPLOY_MODE"
        show_help
        exit 1
    fi

    if [[ -z "$COMPONENTS" ]]; then
        COMPONENTS="all"
    fi
}

# 检查系统要求
check_requirements() {
    log_info "检查系统要求..."

    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        log_error "不支持的操作系统"
        exit 1
    fi

    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi

    if [[ "$DEPLOY_MODE" == "docker" ]]; then
        # 检查Docker
        if ! command -v docker &> /dev/null; then
            log_warn "未找到Docker，将尝试安装..."
            install_docker
        fi

        # 检查Docker Compose
        if ! command -v docker-compose &> /dev/null; then
            log_warn "未找到Docker Compose，将尝试安装..."
            install_docker_compose
        fi
    fi

    log_info "系统要求检查完成"
}

# 安装Docker
install_docker() {
    log_info "安装Docker..."
    
    # 更新包索引
    apt-get update
    
    # 安装必要的包
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # 添加Docker的官方GPG密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # 设置稳定版仓库
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 安装Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
    
    log_info "Docker安装完成"
}

# 安装Docker Compose
install_docker_compose() {
    log_info "安装Docker Compose..."
    
    # 下载Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    # 设置执行权限
    chmod +x /usr/local/bin/docker-compose
    
    log_info "Docker Compose安装完成"
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    mkdir -p /opt/log-monitor/{data,logs,config}
    mkdir -p /opt/log-monitor/service
    mkdir -p /opt/log-monitor/agent/{data,logs,config}
    mkdir -p /opt/log-monitor/frontend
    
    # 为Docker部署创建数据目录
    if [[ "$DEPLOY_MODE" == "docker" ]]; then
        mkdir -p "$SCRIPT_DIR/docker/data/"{service,agent}
        mkdir -p "$SCRIPT_DIR/docker/logs/"{service,agent}
    fi
    
    log_info "目录结构创建完成"
}

# 本地部署Service
deploy_service_local() {
    log_info "本地部署Service..."
    
    cd "$PROJECT_ROOT/service"
    
    # 检查是否已构建
    if [[ ! -f "build/libs/service-1.0.0.jar" ]]; then
        log_info "构建Service..."
        ./gradlew build
    fi
    
    # 运行安装脚本
    bash "$SCRIPT_DIR/scripts/install-service.sh"
    
    log_info "Service本地部署完成"
}

# 本地部署Agent
deploy_agent_local() {
    log_info "本地部署Agent..."
    
    cd "$PROJECT_ROOT/agent"
    
    # 检查是否已构建
    if [[ ! -f "target/release/agent" ]]; then
        log_info "构建Agent..."
        cargo build --release
    fi
    
    # 运行安装脚本
    bash "$SCRIPT_DIR/scripts/install-agent.sh"
    
    log_info "Agent本地部署完成"
}

# 本地部署Frontend
deploy_frontend_local() {
    log_info "本地部署Frontend..."
    
    cd "$PROJECT_ROOT/front"
    
    # 运行安装脚本
    bash "$SCRIPT_DIR/scripts/install-frontend.sh"
    
    log_info "Frontend本地部署完成"
}

# Docker部署
deploy_docker() {
    log_info "Docker部署..."
    
    cd "$SCRIPT_DIR/docker"
    
    # 准备配置文件
    if [[ ! -f "config/application.yml" ]]; then
        cp "$SCRIPT_DIR/config/application.yml" config/
    fi
    
    if [[ ! -f "config/agent.toml" ]]; then
        cp "$SCRIPT_DIR/config/agent.toml" config/
    fi
    
    # 构建和启动容器
    case "$COMPONENTS" in
        "all")
            docker-compose up -d
            ;;
        "service")
            docker-compose up -d service
            ;;
        "agent")
            docker-compose up -d agent
            ;;
        "frontend")
            docker-compose up -d frontend
            ;;
        *)
            # 支持多个组件，如 "service,agent"
            IFS=',' read -ra COMP_ARRAY <<< "$COMPONENTS"
            docker-compose up -d "${COMP_ARRAY[@]}"
            ;;
    esac
    
    log_info "Docker部署完成"
}

# 本地部署
deploy_local() {
    log_info "开始本地部署..."
    
    case "$COMPONENTS" in
        "all")
            deploy_service_local
            deploy_agent_local
            deploy_frontend_local
            ;;
        "service")
            deploy_service_local
            ;;
        "agent")
            deploy_agent_local
            ;;
        "frontend")
            deploy_frontend_local
            ;;
        *)
            # 支持多个组件
            IFS=',' read -ra COMP_ARRAY <<< "$COMPONENTS"
            for comp in "${COMP_ARRAY[@]}"; do
                case "$comp" in
                    "service")
                        deploy_service_local
                        ;;
                    "agent")
                        deploy_agent_local
                        ;;
                    "frontend")
                        deploy_frontend_local
                        ;;
                    *)
                        log_warn "未知组件: $comp"
                        ;;
                esac
            done
            ;;
    esac
    
    log_info "本地部署完成"
}

# 显示部署结果
show_deployment_info() {
    log_info "部署信息:"
    echo
    
    if [[ "$DEPLOY_MODE" == "local" ]]; then
        log_info "本地部署完成！"
        echo
        echo "服务管理命令:"
        echo "  Service:  systemctl {start|stop|restart|status} log-monitor-service"
        echo "  Agent:    systemctl {start|stop|restart|status} log-monitor-agent"
        echo "  Frontend: systemctl {start|stop|restart|status} nginx"
        echo
        echo "配置文件位置:"
        echo "  Service:  /opt/log-monitor/config/application.yml"
        echo "  Agent:    /opt/log-monitor/agent/config/agent.toml"
        echo "  Frontend: /etc/nginx/sites-available/log-monitor"
        echo
        echo "日志位置:"
        echo "  Service:  /opt/log-monitor/logs/"
        echo "  Agent:    /opt/log-monitor/agent/logs/"
        echo "  Frontend: /var/log/nginx/"
        echo
        echo "访问地址:"
        echo "  Frontend: http://log-monitor.local (请配置域名)"
        echo "  Service API: http://localhost:8081/api"
        echo "  Agent WebSocket: ws://localhost:8080"
        
    elif [[ "$DEPLOY_MODE" == "docker" ]]; then
        log_info "Docker部署完成！"
        echo
        echo "Docker管理命令:"
        echo "  查看状态: docker-compose ps"
        echo "  查看日志: docker-compose logs -f [service_name]"
        echo "  停止服务: docker-compose down"
        echo "  重启服务: docker-compose restart [service_name]"
        echo
        echo "访问地址:"
        echo "  Frontend: http://localhost"
        echo "  Service API: http://localhost:8081/api"
        echo "  Agent WebSocket: ws://localhost:8080"
        echo
        echo "数据目录:"
        echo "  Service: $SCRIPT_DIR/docker/data/service"
        echo "  Agent: $SCRIPT_DIR/docker/data/agent"
    fi
}

# 主函数
main() {
    log_info "多Agent日志监控系统 - 一键部署脚本"
    echo
    
    parse_args "$@"
    check_requirements
    create_directories
    
    if [[ "$DEPLOY_MODE" == "local" ]]; then
        deploy_local
    elif [[ "$DEPLOY_MODE" == "docker" ]]; then
        deploy_docker
    fi
    
    show_deployment_info
    
    log_info "部署完成！"
}

# 执行主函数
main "$@" 