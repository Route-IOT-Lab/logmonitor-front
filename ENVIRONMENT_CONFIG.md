# 环境配置说明

## 概述

LogMonitor前端支持通过环境变量进行配置，以适应不同的部署环境。

## 环境变量

### API配置

- `VITE_API_BASE_URL`: API服务的基础URL
  - 开发环境默认: `http://localhost:8081`
  - 生产环境默认: `/api` (相对路径，由nginx代理)

### WebSocket配置

- `VITE_WS_BASE_URL`: WebSocket服务的基础URL
  - 开发环境默认: `ws://localhost:8081`
  - 生产环境默认: 自动从当前域名生成

## 配置方式

### 1. 开发环境

创建 `.env` 文件（基于 `env.example`）：

```bash
# 复制示例文件
cp env.example .env

# 编辑配置
VITE_API_BASE_URL=http://localhost:8081
VITE_WS_BASE_URL=ws://localhost:8081
```

### 2. 生产环境

#### 方式一：使用部署脚本

```bash
# 使用环境变量
SERVICE_URL=http://your-api-server:8081 \
WEBSOCKET_URL=ws://your-ws-server:8081 \
./deploy-frontend.sh

# 或使用命令行参数
./deploy-frontend.sh \
  --service-url http://your-api-server:8081 \
  --websocket-url ws://your-ws-server:8081
```

#### 方式二：使用nginx代理（推荐）

在生产环境中，推荐使用nginx代理，这样前端可以使用相对路径：

1. 前端配置为空（使用默认相对路径）
2. nginx配置代理规则：

```nginx
# API代理
location /api/ {
    proxy_pass http://your-api-server:8081/api/;
    # ... 其他代理设置
}

# WebSocket代理
location /ws {
    proxy_pass http://your-ws-server:8081/ws;
    # ... WebSocket代理设置
}
```

### 3. Docker环境

在Docker环境中，可以通过环境变量传递：

```bash
docker run -e VITE_API_BASE_URL=http://api-server:8081 \
           -e VITE_WS_BASE_URL=ws://ws-server:8081 \
           your-frontend-image
```

## 配置优先级

1. 环境变量 `VITE_API_BASE_URL` / `VITE_WS_BASE_URL`
2. 开发环境默认值
3. 生产环境默认值（相对路径）

## 注意事项

1. **Vite环境变量**: 所有环境变量必须以 `VITE_` 开头才能在客户端代码中访问
2. **构建时注入**: 环境变量在构建时注入，修改后需要重新构建
3. **相对路径**: 生产环境推荐使用相对路径，由nginx代理处理
4. **HTTPS**: 在生产环境中，确保WebSocket使用 `wss://` 协议

## 示例配置

### 开发环境
```bash
VITE_API_BASE_URL=http://localhost:8081
VITE_WS_BASE_URL=ws://localhost:8081
```

### 生产环境（nginx代理）
```bash
# 使用相对路径，由nginx代理
VITE_API_BASE_URL=
VITE_WS_BASE_URL=
```

### 生产环境（直接访问）
```bash
VITE_API_BASE_URL=https://api.example.com
VITE_WS_BASE_URL=wss://ws.example.com
```

# 环境变量配置指南

## 概述

本项目使用环境变量来配置API和WebSocket连接地址，支持开发环境和生产环境的不同配置。

## 环境变量文件

### 1. `env.example` - 环境变量模板
这是环境变量的示例文件，包含所有可配置的变量及其说明。

### 2. `env.prod` - 生产环境配置
你已创建的生产环境配置文件，包含生产环境的API和WebSocket地址。

## 可配置的环境变量

| 变量名 | 说明 | 默认值 | 示例 |
|--------|------|--------|------|
| `VITE_API_BASE_URL` | API服务器基础地址 | `http://localhost:8081` (开发) | `http://192.168.188.120` |
| `VITE_WS_BASE_URL` | WebSocket服务器基础地址 | `ws://localhost:8081` (开发) | `ws://192.168.188.120` |

## 如何使用环境变量

### 1. 开发环境

在开发环境中，Vite会自动加载以下文件（按优先级排序）：
- `.env.local` (本地开发配置，不提交到git)
- `.env.development` (开发环境配置)
- `.env` (通用配置)

**推荐做法：**
```bash
# 复制示例文件
cp env.example .env.local

# 编辑本地配置
nano .env.local
```

### 2. 生产环境

在生产环境中，Vite会加载：
- `.env.production` (生产环境配置)
- `.env` (通用配置)

**推荐做法：**
```bash
# 复制生产配置
cp env.prod .env.production

# 或者直接使用env.prod
```

### 3. 在代码中使用环境变量

环境变量在代码中通过 `import.meta.env` 访问：

```typescript
// API服务中使用
const baseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8081';

// WebSocket服务中使用
const wsUrl = import.meta.env.VITE_WS_BASE_URL || 'ws://localhost:8081';
```

## 当前配置说明

### 你的 `env.prod` 配置：
```
VITE_API_BASE_URL=http://192.168.188.120
VITE_WS_BASE_URL=ws://192.168.188.120
```

这个配置表示：
- API服务器运行在 `192.168.188.120` 上
- WebSocket服务器也运行在 `192.168.188.120` 上
- 使用HTTP协议（非HTTPS）

## 启动命令

### 开发环境
```bash
npm run dev
```

### 生产环境构建
```bash
npm run build
```

### 生产环境预览
```bash
npm run preview
```

## 注意事项

1. **环境变量前缀**：只有以 `VITE_` 开头的环境变量才会被Vite暴露给客户端代码
2. **安全性**：不要在环境变量中存储敏感信息（如密码、密钥等）
3. **端口配置**：如果API服务器运行在非标准端口，需要在URL中指定端口号
4. **协议选择**：
   - 开发环境通常使用 `http://` 和 `ws://`
   - 生产环境建议使用 `https://` 和 `wss://`

## 常见配置场景

### 本地开发
```bash
# .env.local
VITE_API_BASE_URL=http://localhost:8081
VITE_WS_BASE_URL=ws://localhost:8081
```

### 局域网部署
```bash
# .env.production
VITE_API_BASE_URL=http://192.168.1.100:8081
VITE_WS_BASE_URL=ws://192.168.1.100:8081
```

### 公网部署（HTTPS）
```bash
# .env.production
VITE_API_BASE_URL=https://your-domain.com
VITE_WS_BASE_URL=wss://your-domain.com
```

## 故障排除

### 1. 环境变量未生效
- 检查文件名是否正确（`.env.local`, `.env.production` 等）
- 确认变量名以 `VITE_` 开头
- 重启开发服务器

### 2. 连接失败
- 检查API服务器是否正在运行
- 确认IP地址和端口号正确
- 检查防火墙设置

### 3. WebSocket连接失败
- 确认WebSocket服务器已启动
- 检查协议是否正确（ws:// 或 wss://）
- 验证端口是否开放 