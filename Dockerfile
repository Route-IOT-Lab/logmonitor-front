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

# 安装 curl 用于健康检查
RUN apk add --no-cache curl

# 复制构建文件
COPY --from=builder /app/build /usr/share/nginx/html

# 复制 Nginx 配置
COPY nginx-docker.conf /etc/nginx/conf.d/default.conf

# 创建日志文件
RUN touch /var/log/nginx/logmonitor-access.log /var/log/nginx/logmonitor-error.log

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"] 