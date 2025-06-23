#!/bin/bash

# 多Agent日志监控系统 - Service 安装脚本
# 用途: 在生产环境中安装和配置Service组件

set -e

# 配置变量
SERVICE_USER="logmonitor"
SERVICE_GROUP="logmonitor"
INSTALL_DIR="/opt/log-monitor"
SERVICE_DIR="${INSTALL_DIR}/service"
DATA_DIR="${INSTALL_DIR}/data"
LOGS_DIR="${INSTALL_DIR}/logs"
CONFIG_DIR="${INSTALL_DIR}/config"
SYSTEMD_DIR="/etc/systemd/system"

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

# 检查Java环境
check_java() {
    log_info "检查Java环境..."
    if ! command -v java &> /dev/null; then
        log_error "未找到Java，请先安装JDK 17或更高版本"
        exit 1
    fi
    
    JAVA_VERSION=$(java -version 2>&1 | head -n1 | cut -d'"' -f2 | cut -d'.' -f1)
    if [[ $JAVA_VERSION -lt 17 ]]; then
        log_error "需要JDK 17或更高版本，当前版本: $JAVA_VERSION"
        exit 1
    fi
    
    log_info "Java版本检查通过: $JAVA_VERSION"
}

# 创建用户和组
create_user() {
    log_info "创建服务用户和组..."
    
    if ! getent group $SERVICE_GROUP > /dev/null 2>&1; then
        groupadd $SERVICE_GROUP
        log_info "创建组: $SERVICE_GROUP"
    fi
    
    if ! getent passwd $SERVICE_USER > /dev/null 2>&1; then
        useradd -r -g $SERVICE_GROUP -d $INSTALL_DIR -s /bin/false $SERVICE_USER
        log_info "创建用户: $SERVICE_USER"
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    mkdir -p $SERVICE_DIR
    mkdir -p $DATA_DIR
    mkdir -p $LOGS_DIR
    mkdir -p $CONFIG_DIR
    
    # 设置权限
    chown -R $SERVICE_USER:$SERVICE_GROUP $INSTALL_DIR
    chmod 755 $INSTALL_DIR
    chmod 755 $SERVICE_DIR
    chmod 755 $DATA_DIR
    chmod 755 $LOGS_DIR
    chmod 755 $CONFIG_DIR
    
    log_info "目录结构创建完成"
}

# 复制文件
copy_files() {
    log_info "复制Service文件..."
    
    # 检查JAR文件是否存在
    if [[ ! -f "build/libs/service-1.0.0.jar" ]]; then
        log_error "未找到Service JAR文件，请先运行 ./gradlew build"
        exit 1
    fi
    
    # 复制JAR文件
    cp build/libs/service-1.0.0.jar $SERVICE_DIR/
    
    # 复制配置文件
    if [[ -f "deploy/config/application.yml" ]]; then
        cp deploy/config/application.yml $CONFIG_DIR/
    else
        log_warn "未找到配置文件，将使用默认配置"
    fi
    
    # 设置权限
    chown -R $SERVICE_USER:$SERVICE_GROUP $SERVICE_DIR
    chown -R $SERVICE_USER:$SERVICE_GROUP $CONFIG_DIR
    chmod 644 $SERVICE_DIR/service-1.0.0.jar
    
    log_info "文件复制完成"
}

# 创建systemd服务文件
create_systemd_service() {
    log_info "创建systemd服务..."
    
    cat > $SYSTEMD_DIR/log-monitor-service.service << EOF
[Unit]
Description=Log Monitor Service
Documentation=https://github.com/your-repo/log-monitor
After=network.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$SERVICE_DIR
ExecStart=/usr/bin/java -Xmx512m -Xms256m \\
    -Dspring.config.location=$CONFIG_DIR/application.yml \\
    -Dlogging.file.name=$LOGS_DIR/service.log \\
    -jar $SERVICE_DIR/service-1.0.0.jar
ExecStop=/bin/kill -TERM \$MAINPID
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=log-monitor-service

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$DATA_DIR $LOGS_DIR
ProtectHome=true

# 资源限制
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd
    systemctl daemon-reload
    
    log_info "systemd服务创建完成"
}

# 创建日志轮转配置
create_logrotate() {
    log_info "配置日志轮转..."
    
    cat > /etc/logrotate.d/log-monitor-service << EOF
$LOGS_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_GROUP
    postrotate
        systemctl reload log-monitor-service > /dev/null 2>&1 || true
    endscript
}
EOF

    log_info "日志轮转配置完成"
}

# 创建启动脚本
create_start_script() {
    log_info "创建启动脚本..."
    
    cat > $SERVICE_DIR/start.sh << 'EOF'
#!/bin/bash

# Log Monitor Service 启动脚本

SERVICE_NAME="log-monitor-service"

start_service() {
    echo "启动 $SERVICE_NAME..."
    sudo systemctl start $SERVICE_NAME
    sudo systemctl enable $SERVICE_NAME
    echo "$SERVICE_NAME 已启动并设置为开机自启"
}

stop_service() {
    echo "停止 $SERVICE_NAME..."
    sudo systemctl stop $SERVICE_NAME
    echo "$SERVICE_NAME 已停止"
}

restart_service() {
    echo "重启 $SERVICE_NAME..."
    sudo systemctl restart $SERVICE_NAME
    echo "$SERVICE_NAME 已重启"
}

status_service() {
    echo "检查 $SERVICE_NAME 状态..."
    sudo systemctl status $SERVICE_NAME
}

logs_service() {
    echo "查看 $SERVICE_NAME 日志..."
    sudo journalctl -u $SERVICE_NAME -f
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
    status)
        status_service
        ;;
    logs)
        logs_service
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF

    chmod +x $SERVICE_DIR/start.sh
    chown $SERVICE_USER:$SERVICE_GROUP $SERVICE_DIR/start.sh
    
    log_info "启动脚本创建完成"
}

# 主安装流程
main() {
    log_info "开始安装 Log Monitor Service..."
    
    check_root
    check_java
    create_user
    create_directories
    copy_files
    create_systemd_service
    create_logrotate
    create_start_script
    
    log_info "安装完成！"
    echo
    log_info "使用方法:"
    echo "  启动服务: systemctl start log-monitor-service"
    echo "  停止服务: systemctl stop log-monitor-service"
    echo "  查看状态: systemctl status log-monitor-service"
    echo "  查看日志: journalctl -u log-monitor-service -f"
    echo "  或使用脚本: $SERVICE_DIR/start.sh {start|stop|restart|status|logs}"
    echo
    log_info "配置文件位置: $CONFIG_DIR/application.yml"
    log_info "数据目录: $DATA_DIR"
    log_info "日志目录: $LOGS_DIR"
    echo
    log_warn "请根据需要修改配置文件，然后启动服务"
}

# 执行主流程
main "$@" 