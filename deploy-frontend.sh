#!/bin/bash

# LogMonitor 前端自动部署脚本

set -e

# 配置变量
PROJECT_DIR="$(pwd)"
NGINX_DIR="/var/www/logmonitor"
BACKUP_DIR="/backup/logmonitor-frontend"
SERVICE_URL="${SERVICE_URL:-http://localhost:8080}"
WEBSOCKET_URL="${WEBSOCKET_URL:-ws://localhost:8081}"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    log_info "检查部署依赖..."
    
    if ! command -v node &> /dev/null; then
        log_error "Node.js 未安装"
        exit 1
    fi
    
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        log_error "Node.js 版本需要 18 或更高，当前版本: $(node --version)"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_error "npm 未安装"
        exit 1
    fi
    
    if ! command -v nginx &> /dev/null; then
        log_warning "Nginx 未安装，将跳过 Nginx 配置"
    fi
    
    log_success "依赖检查完成"
}

# 备份现有部署
backup_existing() {
    if [[ -d "$NGINX_DIR" ]]; then
        log_info "备份现有部署..."
        sudo mkdir -p "$BACKUP_DIR"
        sudo cp -r "$NGINX_DIR" "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
        log_success "备份完成"
    fi
}

# 安装依赖
install_dependencies() {
    log_info "安装项目依赖..."
    npm ci
    log_success "依赖安装完成"
}

# 构建项目
build_project() {
    log_info "构建生产版本..."
    
    # 设置环境变量
    export VITE_API_BASE_URL="$SERVICE_URL"
    export VITE_WS_BASE_URL="$WEBSOCKET_URL"
    
    npm run build
    log_success "构建完成"
}

# 部署到 Nginx
deploy_to_nginx() {
    if command -v nginx &> /dev/null; then
        log_info "部署到 Nginx..."
        
        # 创建目录
        sudo mkdir -p "$NGINX_DIR"
        
        # 复制文件
        sudo cp -r build/* "$NGINX_DIR/"
        
        # 设置权限
        sudo chown -R www-data:www-data "$NGINX_DIR" 2>/dev/null || sudo chown -R nginx:nginx "$NGINX_DIR" 2>/dev/null || log_warning "无法设置文件所有者"
        sudo chmod -R 755 "$NGINX_DIR"
        
        # 测试 Nginx 配置
        if sudo nginx -t; then
            sudo systemctl reload nginx
            log_success "Nginx 部署完成"
        else
            log_error "Nginx 配置测试失败"
            exit 1
        fi
    else
        log_warning "Nginx 未安装，跳过 Nginx 部署"
        log_info "构建文件位于: $PROJECT_DIR/build/"
    fi
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    # 检查文件是否存在
    if [[ -f "$NGINX_DIR/index.html" ]] || [[ -f "build/index.html" ]]; then
        log_success "静态文件构建成功"
    else
        log_error "静态文件构建失败"
        exit 1
    fi
    
    # 检查 Nginx 状态
    if command -v nginx &> /dev/null; then
        if systemctl is-active --quiet nginx; then
            log_success "Nginx 运行正常"
        else
            log_error "Nginx 未运行"
            exit 1
        fi
        
        # 检查网站可访问性
        sleep 2  # 等待服务启动
        if curl -f -s --max-time 10 http://localhost/ > /dev/null; then
            log_success "网站可访问"
        else
            log_warning "网站可能无法访问，请检查配置"
        fi
    fi
}

# 显示部署信息
show_deployment_info() {
    log_success "=== 部署信息 ==="
    echo "项目目录: $PROJECT_DIR"
    echo "构建目录: $PROJECT_DIR/build"
    if command -v nginx &> /dev/null; then
        echo "Web目录: $NGINX_DIR"
        echo "访问地址: http://localhost/"
    fi
    echo "API地址: $SERVICE_URL"
    echo "WebSocket地址: $WEBSOCKET_URL"
    echo ""
    log_info "如需修改API地址，请使用环境变量："
    echo "SERVICE_URL=http://your-api-server:8080 WEBSOCKET_URL=ws://your-ws-server:8081 ./deploy-frontend.sh"
}

# 主函数
main() {
    log_info "开始 LogMonitor 前端部署..."
    
    check_dependencies
    backup_existing
    install_dependencies
    build_project
    deploy_to_nginx
    health_check
    show_deployment_info
    
    log_success "LogMonitor 前端部署完成！"
}

# 显示帮助
show_help() {
    echo "LogMonitor 前端部署脚本"
    echo ""
    echo "用法: $0 [OPTIONS]"
    echo ""
    echo "选项:"
    echo "  --service-url URL    设置后端服务 URL (默认: http://localhost:8080)"
    echo "  --websocket-url URL  设置 WebSocket URL (默认: ws://localhost:8081)"
    echo "  --nginx-dir DIR      设置 Nginx 部署目录 (默认: /var/www/logmonitor)"
    echo "  --help               显示此帮助信息"
    echo ""
    echo "环境变量:"
    echo "  SERVICE_URL          后端API地址"
    echo "  WEBSOCKET_URL        WebSocket地址"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认配置部署"
    echo "  SERVICE_URL=http://api.example.com $0 # 使用环境变量"
    echo "  $0 --service-url http://api.example.com --websocket-url wss://ws.example.com"
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --service-url)
            SERVICE_URL="$2"
            shift 2
            ;;
        --websocket-url)
            WEBSOCKET_URL="$2"
            shift 2
            ;;
        --nginx-dir)
            NGINX_DIR="$2"
            shift 2
            ;;
        --help)
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

# 运行主函数
main 