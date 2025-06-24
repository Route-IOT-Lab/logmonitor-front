# LogMonitor 前端部署指南

本指南详细说明如何部署 LogMonitor 前端项目到生产环境。

## 📋 项目概述

LogMonitor 前端是基于 SvelteKit 构建的现代Web应用，提供日志监控和管理界面。

### 技术栈
- **框架**: SvelteKit 2.x
- **构建工具**: Vite 5.x
- **UI组件**: Svelte Material UI (SMUI)
- **样式**: Sass/SCSS
- **WebSocket**: 原生WebSocket + ws库

## 🚀 快速部署

### 方法1: 静态文件部署 (推荐)

```bash
# 1. 构建生产版本
npm install
npm run build

# 2. 部署到 Nginx
sudo cp -r build/* /var/www/logmonitor/
sudo systemctl restart nginx
```

### 方法2: 使用部署脚本

```bash
# 使用自动化脚本
chmod +x deploy-frontend.sh
sudo ./deploy-frontend.sh
```

### 方法3: Docker 部署

```bash
# 构建镜像
docker build -t logmonitor-frontend .

# 运行容器
docker run -d -p 80:80 --name logmonitor-frontend logmonitor-frontend
```

## 📁 详细部署步骤

### 1. 准备环境

#### 1.1 安装 Node.js
```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# CentOS/RHEL
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# 验证安装
node --version  # 应该是 18.x 或更高
npm --version
```

#### 1.2 安装 Nginx
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx

# CentOS/RHEL
sudo yum install nginx
# 或者
sudo dnf install nginx

# 启动并启用
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 2. 构建项目

#### 2.1 安装依赖
```bash
cd /path/to/logmonitor/front
npm install
```

#### 2.2 配置环境变量
创建 `.env.production` 文件：
```bash
# API 配置
VITE_API_URL=http://your-domain.com/api
VITE_WS_URL=wss://your-domain.com/ws

# 应用配置
VITE_APP_TITLE=LogMonitor
VITE_APP_VERSION=1.0.0
```

#### 2.3 构建生产版本
```bash
npm run build
```

构建完成后，静态文件将生成在 `build/` 目录中。

### 3. Nginx 配置

#### 3.1 创建站点配置
```bash
sudo nano /etc/nginx/sites-available/logmonitor
```

**完整的 Nginx 配置:**
```nginx
server {
    listen 80;
    server_name your-domain.com;  # 替换为您的域名
    root /var/www/logmonitor;
    index index.html;

    # 日志配置
    access_log /var/log/nginx/logmonitor-access.log;
    error_log /var/log/nginx/logmonitor-error.log;

    # 启用 Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json
        image/svg+xml;

    # 静态文件缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # SPA 路由支持
    location / {
        try_files $uri $uri/ /index.html;
        
        # 防止缓存 HTML 文件
        location ~* \.html$ {
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }
    }

    # API 代理到后端服务
    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 超时设置
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # WebSocket 代理
    location /ws {
        proxy_pass http://localhost:8081/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 特殊设置
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 30s;
    }

    # 安全头设置
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # 内容安全策略
    add_header Content-Security-Policy "
        default-src 'self';
        script-src 'self' 'unsafe-inline' 'unsafe-eval';
        style-src 'self' 'unsafe-inline' fonts.googleapis.com;
        font-src 'self' fonts.gstatic.com;
        img-src 'self' data: blob:;
        connect-src 'self' ws: wss:;
        frame-ancestors 'none';
    " always;
}
```

#### 3.2 启用站点
```bash
# 创建 Web 目录
sudo mkdir -p /var/www/logmonitor

# 复制构建文件
sudo cp -r build/* /var/www/logmonitor/

# 设置权限
sudo chown -R www-data:www-data /var/www/logmonitor
sudo chmod -R 755 /var/www/logmonitor

# 启用站点
sudo ln -s /etc/nginx/sites-available/logmonitor /etc/nginx/sites-enabled/

# 删除默认站点（可选）
sudo rm -f /etc/nginx/sites-enabled/default

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

## 🔧 自动化部署脚本

创建 `deploy-frontend.sh`:

```bash
#!/bin/bash

# LogMonitor 前端自动部署脚本

set -e

# 配置变量
PROJECT_DIR="/opt/logmonitor/frontend"
NGINX_DIR="/var/www/logmonitor"
BACKUP_DIR="/backup/logmonitor-frontend"
SERVICE_URL="http://localhost:8080"
WEBSOCKET_URL="ws://localhost:8081"

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
        mkdir -p "$BACKUP_DIR"
        cp -r "$NGINX_DIR" "$BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
        log_success "备份完成"
    fi
}

# 安装依赖
install_dependencies() {
    log_info "安装项目依赖..."
    npm ci --only=production
    log_success "依赖安装完成"
}

# 构建项目
build_project() {
    log_info "构建生产版本..."
    
    # 设置环境变量
    export VITE_API_URL="$SERVICE_URL"
    export VITE_WS_URL="$WEBSOCKET_URL"
    
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
        sudo chown -R www-data:www-data "$NGINX_DIR"
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
    fi
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    # 检查文件是否存在
    if [[ -f "$NGINX_DIR/index.html" ]]; then
        log_success "静态文件部署成功"
    else
        log_error "静态文件部署失败"
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
    fi
    
    # 检查网站可访问性
    if curl -f -s http://localhost/ > /dev/null; then
        log_success "网站可访问"
    else
        log_warning "网站可能无法访问，请检查配置"
    fi
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
    
    log_success "LogMonitor 前端部署完成！"
    log_info "访问地址: http://localhost/"
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
```

## 🐳 Docker 部署

### Dockerfile
```dockerfile
# 构建阶段
FROM node:18-alpine AS builder

WORKDIR /app

# 复制依赖文件
COPY package*.json ./
RUN npm ci --only=production

# 复制源代码
COPY . .

# 构建应用
RUN npm run build

# 生产阶段
FROM nginx:alpine

# 复制构建文件
COPY --from=builder /app/build /usr/share/nginx/html

# 复制 Nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露端口
EXPOSE 80

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"]
```

### Docker Compose
```yaml
version: '3.8'

services:
  frontend:
    build: .
    ports:
      - "80:80"
    depends_on:
      - service
    environment:
      - VITE_API_URL=http://localhost:8080/api
      - VITE_WS_URL=ws://localhost:8081/ws
    restart: unless-stopped
    
  # 可选：包含完整的服务栈
  service:
    image: logmonitor-service:latest
    ports:
      - "8080:8080"
    
  agent:
    image: logmonitor-agent:latest
    ports:
      - "8081:8081"
```

## 🔒 安全配置

### SSL/HTTPS 配置

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    # SSL 证书
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # 其他配置...
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

### 使用 Let's Encrypt
```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d your-domain.com

# 自动续期
sudo crontab -e
# 添加: 0 12 * * * /usr/bin/certbot renew --quiet
```

## 📊 监控和维护

### 性能监控

#### 1. Nginx 日志分析
```bash
# 实时查看访问日志
tail -f /var/log/nginx/logmonitor-access.log

# 分析最常访问的页面
awk '{print $7}' /var/log/nginx/logmonitor-access.log | sort | uniq -c | sort -nr

# 分析响应时间
awk '{print $NF}' /var/log/nginx/logmonitor-access.log | sort -n
```

#### 2. 性能指标收集
```javascript
// 添加到 app.html
<script>
window.addEventListener('load', () => {
    const perfData = performance.getEntriesByType('navigation')[0];
    
    // 发送性能数据到分析服务
    fetch('/api/analytics/performance', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            loadTime: perfData.loadEventEnd - perfData.fetchStart,
            domContentLoaded: perfData.domContentLoadedEventEnd - perfData.fetchStart,
            firstContentfulPaint: performance.getEntriesByName('first-contentful-paint')[0]?.startTime
        })
    });
});
</script>
```

### 健康检查

#### 自动化健康检查脚本
```bash
#!/bin/bash
# health-check.sh

URL="http://localhost"
EXPECTED_STATUS=200
TIMEOUT=10

# 检查 HTTP 响应
status=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT $URL)

if [ $status -eq $EXPECTED_STATUS ]; then
    echo "✅ 前端健康检查通过: $URL 返回 $status"
    
    # 检查关键页面
    if curl -s --max-time $TIMEOUT "$URL/agents" | grep -q "Agents"; then
        echo "✅ 关键页面检查通过"
    else
        echo "⚠️ 关键页面可能有问题"
        exit 1
    fi
else
    echo "❌ 前端健康检查失败: $URL 返回 $status"
    exit 1
fi
```

### 备份策略

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backup/logmonitor-frontend"
DATE=$(date +%Y%m%d_%H%M%S)

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份静态文件
tar -czf "$BACKUP_DIR/static-$DATE.tar.gz" /var/www/logmonitor/

# 备份 Nginx 配置
tar -czf "$BACKUP_DIR/nginx-config-$DATE.tar.gz" /etc/nginx/sites-available/logmonitor

# 清理旧备份（保留最近7天）
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "备份完成: $DATE"
```

## 🚀 CI/CD 集成

### GitHub Actions
```yaml
name: Deploy Frontend

on:
  push:
    branches: [main]
    paths: ['front/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: front/package-lock.json
    
    - name: Install dependencies
      working-directory: front
      run: npm ci
    
    - name: Build
      working-directory: front
      run: npm run build
      env:
        VITE_API_URL: ${{ secrets.API_URL }}
        VITE_WS_URL: ${{ secrets.WS_URL }}
    
    - name: Deploy to server
      uses: appleboy/ssh-action@v0.1.5
      with:
        host: ${{ secrets.HOST }}
        username: ${{ secrets.USERNAME }}
        key: ${{ secrets.SSH_KEY }}
        script: |
          cd /opt/logmonitor/frontend
          git pull origin main
          ./deploy-frontend.sh
```

## 📝 故障排除

### 常见问题

1. **构建失败**
```bash
# 清理缓存
rm -rf node_modules package-lock.json .svelte-kit
npm install

# 检查 Node.js 版本
node --version  # 需要 18+
```

2. **WebSocket 连接失败**
```bash
# 检查代理配置
curl -I http://localhost/ws

# 检查后端服务
curl http://localhost:8081/ws
```

3. **API 请求失败**
```bash
# 检查后端服务
curl http://localhost:8080/api/agents

# 检查代理配置
curl http://localhost/api/agents
```

4. **Nginx 配置错误**
```bash
# 测试配置
sudo nginx -t

# 查看错误日志
sudo tail -f /var/log/nginx/error.log
```

5. **权限问题**
```bash
# 修复文件权限
sudo chown -R www-data:www-data /var/www/logmonitor
sudo chmod -R 755 /var/www/logmonitor
```

## 📈 性能优化

### 构建优化

修改 `vite.config.ts`:
```typescript
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
    plugins: [sveltekit()],
    build: {
        minify: 'terser',
        terserOptions: {
            compress: {
                drop_console: true,
                drop_debugger: true
            }
        },
        rollupOptions: {
            output: {
                manualChunks: {
                    vendor: ['svelte', '@sveltejs/kit'],
                    ui: ['@smui/button', '@smui/card', '@smui/data-table']
                }
            }
        }
    }
});
```

### Nginx 优化
```nginx
# 启用 HTTP/2
listen 443 ssl http2;

# 启用 Brotli 压缩（如果可用）
brotli on;
brotli_comp_level 6;
brotli_types text/plain text/css application/json application/javascript text/xml application/xml;

# 连接保活
keepalive_timeout 65;
keepalive_requests 100;

# 缓存优化
open_file_cache max=1000 inactive=20s;
open_file_cache_valid 30s;
open_file_cache_min_uses 2;
```

---

🎉 **部署完成后，您可以通过以下方式访问 LogMonitor：**

- **本地访问**: http://localhost/
- **生产访问**: https://your-domain.com/
- **健康检查**: http://localhost/health
- **API 文档**: http://localhost/api/docs 