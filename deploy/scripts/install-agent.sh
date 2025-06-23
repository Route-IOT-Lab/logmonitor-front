#!/bin/bash

# 多Agent日志监控系统 - Agent 安装脚本
# 用途: 在生产环境中安装和配置Agent组件

set -e

# 配置变量
SERVICE_USER="logmonitor"
SERVICE_GROUP="logmonitor"
INSTALL_DIR="/opt/log-monitor"
AGENT_DIR="${INSTALL_DIR}/agent"
DATA_DIR="${AGENT_DIR}/data"
LOGS_DIR="${AGENT_DIR}/logs"
CONFIG_DIR="${AGENT_DIR}/config"
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

# 检查Rust环境（如果需要编译）
check_rust() {
    log_info "检查Rust环境..."
    if ! command -v cargo &> /dev/null; then
        log_warn "未找到Rust，将尝试安装..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    fi
    
    log_info "Rust环境检查通过"
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
    
    mkdir -p $AGENT_DIR
    mkdir -p $DATA_DIR
    mkdir -p $LOGS_DIR
    mkdir -p $CONFIG_DIR
    
    # 设置权限
    chown -R $SERVICE_USER:$SERVICE_GROUP $AGENT_DIR
    chmod 755 $AGENT_DIR
    chmod 755 $DATA_DIR
    chmod 755 $LOGS_DIR
    chmod 755 $CONFIG_DIR
    
    log_info "目录结构创建完成"
}

# 复制文件
copy_files() {
    log_info "复制Agent文件..."
    
    # 检查二进制文件是否存在
    if [[ ! -f "target/release/agent" ]]; then
        log_error "未找到Agent二进制文件，请先运行 cargo build --release"
        exit 1
    fi
    
    # 复制二进制文件
    cp target/release/agent $AGENT_DIR/
    
    # 复制配置文件
    if [[ -f "deploy/config/agent.toml" ]]; then
        cp deploy/config/agent.toml $CONFIG_DIR/
    else
        log_warn "未找到配置文件，将使用默认配置"
    fi
    
    # 设置权限
    chown -R $SERVICE_USER:$SERVICE_GROUP $AGENT_DIR
    chmod 755 $AGENT_DIR/agent
    
    log_info "文件复制完成"
}

# 创建systemd服务文件
create_systemd_service() {
    log_info "创建systemd服务..."
    
    cat > $SYSTEMD_DIR/log-monitor-agent.service << EOF
[Unit]
Description=Log Monitor Agent
Documentation=https://github.com/your-repo/log-monitor
After=network.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$AGENT_DIR
ExecStart=$AGENT_DIR/agent --config $CONFIG_DIR/agent.toml
ExecStop=/bin/kill -TERM \$MAINPID
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=log-monitor-agent

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$DATA_DIR $LOGS_DIR /var/log
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
    
    cat > /etc/logrotate.d/log-monitor-agent << EOF
$LOGS_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_GROUP
    postrotate
        systemctl reload log-monitor-agent > /dev/null 2>&1 || true
    endscript
}
EOF

    log_info "日志轮转配置完成"
}

# 创建启动脚本
create_start_script() {
    log_info "创建启动脚本..."
    
    cat > $AGENT_DIR/start.sh << 'EOF'
#!/bin/bash

# Log Monitor Agent 启动脚本

SERVICE_NAME="log-monitor-agent"

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

    chmod +x $AGENT_DIR/start.sh
    chown $SERVICE_USER:$SERVICE_GROUP $AGENT_DIR/start.sh
    
    log_info "启动脚本创建完成"
}

# 主安装流程
main() {
    log_info "开始安装 Log Monitor Agent..."
    
    check_root
    create_user
    create_directories
    copy_files
    create_systemd_service
    create_logrotate
    create_start_script
    
    log_info "安装完成！"
    echo
    log_info "使用方法:"
    echo "  启动服务: systemctl start log-monitor-agent"
    echo "  停止服务: systemctl stop log-monitor-agent"
    echo "  查看状态: systemctl status log-monitor-agent"
    echo "  查看日志: journalctl -u log-monitor-agent -f"
    echo "  或使用脚本: $AGENT_DIR/start.sh {start|stop|restart|status|logs}"
    echo
    log_info "配置文件位置: $CONFIG_DIR/agent.toml"
    log_info "数据目录: $DATA_DIR"
    log_info "日志目录: $LOGS_DIR"
    echo
    log_warn "请根据需要修改配置文件，然后启动服务"
}

# 执行主流程
main "$@" 