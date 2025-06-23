#!/bin/bash

# 多Agent日志监控系统 - Frontend 安装脚本
# 用途: 在生产环境中安装和配置Frontend组件

set -e

# 配置变量
SERVICE_USER="www-data"
SERVICE_GROUP="www-data"
INSTALL_DIR="/opt/log-monitor"
FRONTEND_DIR="${INSTALL_DIR}/frontend"
WEB_ROOT="/var/www/log-monitor"
NGINX_CONF="/etc/nginx/sites-available/log-monitor"
NGINX_ENABLED="/etc/nginx/sites-enabled/log-monitor"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        exit 1
    fi
}

# 检查Node.js环境
check_nodejs() {
    log_info "检查Node.js环境..."
    if ! command -v node &> /dev/null; then
        log_error "未找到Node.js，请先安装Node.js 18或更高版本"
        exit 1
    fi
    
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [[ $NODE_VERSION -lt 18 ]]; then
        log_error "需要Node.js 18或更高版本，当前版本: $NODE_VERSION"
        exit 1
    fi
    
    log_info "Node.js版本检查通过: $NODE_VERSION"
}

# 检查Nginx
check_nginx() {
    log_info "检查Nginx..."
    if ! command -v nginx &> /dev/null; then
        log_warn "未找到Nginx，将尝试安装..."
        apt-get update
        apt-get install -y nginx
    fi
    
    log_info "Nginx检查通过"
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    mkdir -p $FRONTEND_DIR
    mkdir -p $WEB_ROOT
    
    # 设置权限
    chown -R $SERVICE_USER:$SERVICE_GROUP $WEB_ROOT
    chmod 755 $WEB_ROOT
    
    log_info "目录结构创建完成"
}

# 构建和复制文件
build_and_copy() {
    log_info "构建Frontend..."
    
    # 检查是否在前端项目目录
    if [[ ! -f "package.json" ]]; then
        log_error "未找到package.json，请在前端项目目录中运行此脚本"
        exit 1
    fi
    
    # 安装依赖
    npm ci
    
    # 构建生产版本
    npm run build
    
    # 复制构建文件
    if [[ -d "build" ]]; then
        cp -r build/* $WEB_ROOT/
    else
        log_error "构建目录不存在，构建失败"
        exit 1
    fi
    
    # 设置权限
    chown -R $SERVICE_USER:$SERVICE_GROUP $WEB_ROOT
    find $WEB_ROOT -type f -exec chmod 644 {} \;
    find $WEB_ROOT -type d -exec chmod 755 {} \;
    
    log_info "文件复制完成"
}

# 创建Nginx配置
create_nginx_config() {
    log_info "创建Nginx配置..."
    
    cat > $NGINX_CONF << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name log-monitor.local;  # 请修改为您的域名

    root /var/www/log-monitor;
    index index.html;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # 静态文件缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri =404;
    }

    # SPA路由支持
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API代理到Service
    location /api/ {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket代理到Service
    location /ws {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
    }

    # 错误页面
    error_page 404 /index.html;
    error_page 500 502 503 504 /index.html;

    # 日志
    access_log /var/log/nginx/log-monitor-access.log;
    error_log /var/log/nginx/log-monitor-error.log;
}
EOF

    # 启用站点
    if [[ ! -L $NGINX_ENABLED ]]; then
        ln -s $NGINX_CONF $NGINX_ENABLED
    fi
    
    # 测试Nginx配置
    nginx -t
    
    log_info "Nginx配置创建完成"
}

# 创建SSL配置（可选）
create_ssl_config() {
    log_info "创建SSL配置模板..."
    
    cat > "${NGINX_CONF}.ssl" << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name log-monitor.local;  # 请修改为您的域名
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name log-monitor.local;  # 请修改为您的域名

    # SSL证书配置 - 请修改为您的证书路径
    ssl_certificate /path/to/your/certificate.crt;
    ssl_certificate_key /path/to/your/private.key;

    # SSL安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    root /var/www/log-monitor;
    index index.html;

    # 其他配置与HTTP版本相同...
    # （此处省略，与上面的HTTP配置相同）
}
EOF

    log_info "SSL配置模板已创建: ${NGINX_CONF}.ssl"
    log_warn "请配置SSL证书后手动启用SSL配置"
}

# 创建启动脚本
create_start_script() {
    log_info "创建启动脚本..."
    
    cat > $FRONTEND_DIR/start.sh << 'EOF'
#!/bin/bash

# Log Monitor Frontend 启动脚本

start_service() {
    echo "启动 Nginx..."
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo "Frontend 已启动"
}

stop_service() {
    echo "停止 Nginx..."
    sudo systemctl stop nginx
    echo "Frontend 已停止"
}

restart_service() {
    echo "重启 Nginx..."
    sudo systemctl restart nginx
    echo "Frontend 已重启"
}

reload_service() {
    echo "重新加载 Nginx 配置..."
    sudo nginx -t && sudo systemctl reload nginx
    echo "Nginx 配置已重新加载"
}

status_service() {
    echo "检查 Nginx 状态..."
    sudo systemctl status nginx
}

logs_service() {
    echo "查看 Nginx 日志..."
    sudo tail -f /var/log/nginx/log-monitor-access.log
}

case "$1" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    reload)
        reload_service
        ;;
    status)
        status_service
        ;;
    logs)
        logs_service
        ;;
    *)
        echo "用法: $0 {start|stop|restart|reload|status|logs}"
        exit 1
        ;;
esac
EOF

    chmod +x $FRONTEND_DIR/start.sh
    
    log_info "启动脚本创建完成"
}

# 主安装流程
main() {
    log_info "开始安装 Log Monitor Frontend..."
    
    check_root
    check_nodejs
    check_nginx
    create_directories
    build_and_copy
    create_nginx_config
    create_ssl_config
    create_start_script
    
    # 重启Nginx
    systemctl restart nginx
    
    log_info "安装完成！"
    echo
    log_info "使用方法:"
    echo "  启动服务: systemctl start nginx"
    echo "  停止服务: systemctl stop nginx"
    echo "  重启服务: systemctl restart nginx"
    echo "  重新加载配置: nginx -s reload"
    echo "  或使用脚本: $FRONTEND_DIR/start.sh {start|stop|restart|reload|status|logs}"
    echo
    log_info "Web根目录: $WEB_ROOT"
    log_info "Nginx配置: $NGINX_CONF"
    log_info "访问地址: http://log-monitor.local (请配置域名或修改hosts文件)"
    echo
    log_warn "请根据需要修改Nginx配置中的域名和SSL证书路径"
}

# 执行主流程
main "$@" 