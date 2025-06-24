# LogMonitor 前端快速部署指南

## 🎯 关键信息

### SvelteKit 构建输出说明
- **`.svelte-kit/output/client/`** - 浏览器端代码（开发时使用）
- **`.svelte-kit/output/server/`** - 服务端渲染代码（开发时使用）
- **`build/`** - **实际部署用的静态文件**（生产部署）

## 🚀 快速部署步骤

### 1. 构建生产版本
```bash
# 安装依赖
npm install

# 构建静态文件
npm run build
```

构建完成后，`build/` 目录包含：
```
build/
├── index.html          # 主页面
├── _app/              # 应用资源 (JS/CSS)
├── favicon.png        # 网站图标
└── 其他静态文件
```

### 2. 部署方式选择

#### 方式A: 使用自动部署脚本 (推荐)
```bash
# 使用默认配置
sudo ./deploy-frontend.sh

# 自定义后端地址
SERVICE_URL=http://your-server:8080 WEBSOCKET_URL=ws://your-server:8081 ./deploy-frontend.sh
```

#### 方式B: 手动部署到 Nginx
```bash
# 1. 复制文件到 Web 目录
sudo cp -r build/* /var/www/logmonitor/

# 2. 设置权限
sudo chown -R www-data:www-data /var/www/logmonitor
sudo chmod -R 755 /var/www/logmonitor

# 3. 配置 Nginx (使用提供的配置文件)
sudo cp nginx-logmonitor.conf /etc/nginx/sites-available/logmonitor
sudo ln -s /etc/nginx/sites-available/logmonitor /etc/nginx/sites-enabled/

# 4. 重启 Nginx
sudo nginx -t && sudo systemctl reload nginx
```

#### 方式C: Docker 部署
```bash
# 构建镜像
docker build -t logmonitor-frontend .

# 运行容器
docker run -d -p 80:80 --name logmonitor-frontend logmonitor-frontend
```

### 3. 验证部署
```bash
# 检查网站可访问
curl -I http://localhost/

# 检查 API 代理
curl http://localhost/api/agents

# 检查 WebSocket 代理
curl -I http://localhost/ws
```

## 🔧 配置说明

### 环境变量配置
创建 `.env.production` 文件：
```bash
VITE_API_URL=http://your-domain.com/api
VITE_WS_URL=wss://your-domain.com/ws
```

### 后端地址配置
前端需要连接到后端服务：
- **API 服务**: 默认 `http://localhost:8080/api`
- **WebSocket**: 默认 `ws://localhost:8081/ws`

## 📁 目录结构对照表

| 目录/文件 | 用途 | 部署时使用 |
|----------|------|----------|
| `src/` | 源代码 | ❌ |
| `node_modules/` | 依赖包 | ❌ |
| `.svelte-kit/output/client/` | 浏览器端代码 | ❌ |
| `.svelte-kit/output/server/` | 服务端代码 | ❌ |
| **`build/`** | **生产静态文件** | ✅ **部署此目录** |

## 🌐 访问地址

部署完成后：
- **前端界面**: http://localhost/ 或 https://your-domain.com/
- **API 代理**: http://localhost/api/
- **WebSocket**: ws://localhost/ws

## ⚠️ 常见问题

### 1. 构建失败
```bash
# 清理缓存重新构建
rm -rf node_modules package-lock.json .svelte-kit
npm install
npm run build
```

### 2. 页面空白
- 检查 `build/index.html` 是否存在
- 检查浏览器控制台错误
- 确认 Nginx 配置正确

### 3. API 请求失败
- 检查后端服务是否运行在 8080 端口
- 检查 Nginx 代理配置
- 验证防火墙设置

### 4. WebSocket 连接失败
- 检查后端 WebSocket 服务是否运行在 8081 端口
- 确认 Nginx WebSocket 代理配置
- 检查 SSL 证书配置（如使用 HTTPS）

## 📝 部署检查清单

- [ ] Node.js 18+ 已安装
- [ ] 项目依赖已安装 (`npm install`)
- [ ] 构建成功完成 (`npm run build`)
- [ ] `build/` 目录包含 `index.html`
- [ ] Nginx 已安装并配置
- [ ] 后端服务正在运行
- [ ] 防火墙已开放必要端口
- [ ] 域名解析正确（如使用域名）

---

🎉 **部署完成后即可通过浏览器访问 LogMonitor 前端界面！** 