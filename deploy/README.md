# 多Agent日志监控系统 - 部署指南

本文档详细说明如何在生产环境中部署多Agent日志监控系统。

## 📋 目录结构

```
deploy/
├── README.md                    # 部署说明文档
├── deploy.sh                    # 一键部署脚本
├── config/                      # 配置文件模板
│   ├── application.yml         # Service配置
│   └── agent.toml              # Agent配置
├── scripts/                     # 安装脚本
│   ├── install-service.sh      # Service安装脚本
│   ├── install-agent.sh        # Agent安装脚本
│   └── install-frontend.sh     # Frontend安装脚本
└── docker/                      # Docker部署
    ├── docker-compose.yml      # Docker Compose配置
    ├── Dockerfile.service      # Service Dockerfile
    ├── Dockerfile.agent        # Agent Dockerfile
    └── nginx/                   # Nginx配置
        └── log-monitor.conf     # 站点配置
```

## 🚀 快速部署

### 一键部署脚本

最简单的部署方式是使用一键部署脚本：

```bash
# 本地部署所有组件
sudo ./deploy/deploy.sh -m local -c all

# Docker部署所有组件
sudo ./deploy/deploy.sh -m docker -c all

# 仅部署Service组件
sudo ./deploy/deploy.sh -m local -c service

# 部署Service和Agent
sudo ./deploy/deploy.sh -m docker -c service,agent
```

### 部署选项

- **部署模式** (`-m|--mode`):
  - `local`: 本地部署，使用systemd管理服务
  - `docker`: Docker容器部署

- **组件选择** (`-c|--components`):
  - `all`: 部署所有组件
  - `service`: 仅部署Service组件
  - `agent`: 仅部署Agent组件
  - `frontend`: 仅部署Frontend组件
  - `service,agent`: 部署多个组件（逗号分隔）

## 🏗️ 本地部署

### 系统要求

- **操作系统**: Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- **Service**: JDK 17+, systemd
- **Agent**: Rust 1.70+ (可选，如果需要编译), systemd
- **Frontend**: Node.js 18+, Nginx

### 手动部署步骤

#### 1. 部署Service

```bash
cd service

# 构建项目
./gradlew build

# 运行安装脚本
sudo bash deploy/scripts/install-service.sh

# 启动服务
sudo systemctl start log-monitor-service
sudo systemctl enable log-monitor-service
```

#### 2. 部署Agent

```bash
cd agent

# 构建项目
cargo build --release

# 运行安装脚本
sudo bash deploy/scripts/install-agent.sh

# 启动服务
sudo systemctl start log-monitor-agent
sudo systemctl enable log-monitor-agent
```

#### 3. 部署Frontend

```bash
cd front

# 运行安装脚本
sudo bash deploy/scripts/install-frontend.sh

# 启动Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 配置文件

部署后的配置文件位置：

- **Service**: `/opt/log-monitor/config/application.yml`
- **Agent**: `/opt/log-monitor/agent/config/agent.toml`
- **Frontend**: `/etc/nginx/sites-available/log-monitor`

### 服务管理

```bash
# Service
sudo systemctl {start|stop|restart|status} log-monitor-service
sudo journalctl -u log-monitor-service -f

# Agent
sudo systemctl {start|stop|restart|status} log-monitor-agent
sudo journalctl -u log-monitor-agent -f

# Frontend (Nginx)
sudo systemctl {start|stop|restart|status} nginx
sudo tail -f /var/log/nginx/log-monitor-access.log
```

## 🐳 Docker部署

### 系统要求

- **操作系统**: 支持Docker的Linux发行版
- **Docker**: 20.10+
- **Docker Compose**: 2.0+

### 部署步骤

1. **准备环境**
```bash
# 安装Docker和Docker Compose（如果未安装）
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安装Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

2. **配置文件**
```bash
cd deploy/docker

# 复制配置文件模板
cp ../config/application.yml config/
cp ../config/agent.toml config/

# 根据需要修改配置
vim config/application.yml
vim config/agent.toml
```

3. **启动服务**
```bash
# 启动所有服务
docker-compose up -d

# 启动特定服务
docker-compose up -d service agent

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f service
```

### Docker管理命令

```bash
# 查看容器状态
docker-compose ps

# 查看实时日志
docker-compose logs -f [service_name]

# 重启服务
docker-compose restart [service_name]

# 停止所有服务
docker-compose down

# 重新构建并启动
docker-compose up -d --build

# 进入容器
docker-compose exec service bash
```

## ⚙️ 配置说明

### Service配置 (application.yml)

```yaml
server:
  host: "0.0.0.0"          # 监听地址
  port: 8081               # 监听端口
  
database:
  path: "/opt/log-monitor/data/service.db"  # 数据库路径
  
websocket:
  path: "/ws"              # WebSocket路径
  
cors:
  enabled: true            # 启用CORS
  allowed_origins:         # 允许的来源
    - "http://localhost:3000"
    - "https://your-domain.com"
```

### Agent配置 (agent.toml)

```toml
[server]
host = "0.0.0.0"          # 监听地址
port = 8080               # 监听端口
use_tls = false           # 是否使用TLS

[database]
path = "/opt/log-monitor/agent/data/agent.db"  # 数据库路径

[logging]
level = "info"            # 日志级别
file = "/opt/log-monitor/agent/logs/agent.log"  # 日志文件

[security]
allowed_file_paths = [    # 允许监控的文件路径
    "/var/log/",
    "/opt/log-monitor/test-logs/"
]
```

### Nginx配置

Frontend通过Nginx提供服务，配置文件包含：

- 静态文件服务
- API代理到Service
- WebSocket代理
- SSL支持（可选）
- 安全头设置
- Gzip压缩

## 📂 目录结构

部署后的目录结构：

```
/opt/log-monitor/
├── service/                 # Service程序
│   ├── service-1.0.0.jar   # JAR文件
│   └── start.sh            # 启动脚本
├── agent/                   # Agent程序
│   ├── agent               # 二进制文件
│   ├── data/               # 数据目录
│   ├── logs/               # 日志目录
│   ├── config/             # 配置目录
│   └── start.sh            # 启动脚本
├── frontend/               # Frontend程序
│   └── start.sh            # 启动脚本
├── data/                   # Service数据目录
├── logs/                   # Service日志目录
└── config/                 # Service配置目录
```

## 🔧 故障排除

### 常见问题

1. **Service无法启动**
```bash
# 检查Java版本
java -version

# 检查端口占用
sudo netstat -tlnp | grep 8081

# 查看服务日志
sudo journalctl -u log-monitor-service -f
```

2. **Agent连接失败**
```bash
# 检查Agent状态
sudo systemctl status log-monitor-agent

# 检查网络连通性
telnet localhost 8080

# 查看Agent日志
sudo journalctl -u log-monitor-agent -f
```

3. **Frontend无法访问**
```bash
# 检查Nginx状态
sudo systemctl status nginx

# 测试Nginx配置
sudo nginx -t

# 查看Nginx日志
sudo tail -f /var/log/nginx/error.log
```

### 日志位置

- **Service**: `/opt/log-monitor/logs/service.log`
- **Agent**: `/opt/log-monitor/agent/logs/agent.log`
- **Nginx**: `/var/log/nginx/log-monitor-*.log`
- **systemd**: `journalctl -u service-name`

### 性能调优

1. **Service JVM参数**
```bash
# 编辑systemd服务文件
sudo systemctl edit log-monitor-service

# 添加JVM参数
[Service]
Environment="JAVA_OPTS=-Xmx1g -Xms512m -XX:+UseG1GC"
```

2. **Nginx优化**
```nginx
# 编辑Nginx配置
worker_processes auto;
worker_connections 1024;
keepalive_timeout 65;
```

## 🔒 安全建议

1. **防火墙配置**
```bash
# 只开放必要端口
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8081/tcp  # 如果需要直接访问Service API
```

2. **SSL证书配置**
```bash
# 使用Let's Encrypt
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

3. **文件权限**
```bash
# 检查关键文件权限
ls -la /opt/log-monitor/
ls -la /etc/nginx/sites-available/
```

## 📈 监控和维护

### 健康检查

```bash
# Service健康检查
curl -f http://localhost:8081/api/status

# Agent健康检查
curl -f http://localhost:8080/health

# Frontend健康检查
curl -f http://localhost/
```

### 备份策略

```bash
# 备份数据库
cp /opt/log-monitor/data/service.db /backup/
cp /opt/log-monitor/agent/data/agent.db /backup/

# 备份配置
tar -czf /backup/config-$(date +%Y%m%d).tar.gz \
    /opt/log-monitor/config/ \
    /opt/log-monitor/agent/config/ \
    /etc/nginx/sites-available/log-monitor
```

### 日志轮转

系统会自动配置logrotate来管理日志文件，配置文件位于：
- `/etc/logrotate.d/log-monitor-service`
- `/etc/logrotate.d/log-monitor-agent`

## 📞 获取帮助

如果遇到问题，可以：

1. 查看日志文件获取详细错误信息
2. 检查配置文件是否正确
3. 确认所有依赖服务正在运行
4. 参考API文档进行调试

---

🎉 部署完成后，您可以通过浏览器访问前端界面来管理和监控您的日志系统！ 