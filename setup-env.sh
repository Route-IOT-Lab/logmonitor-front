#!/bin/bash

# 环境变量设置脚本

echo "🚀 环境变量设置工具"
echo "=================="

# 检查当前目录
if [ ! -f "package.json" ]; then
    echo "❌ 错误：请在项目根目录运行此脚本"
    exit 1
fi

echo "请选择要创建的环境配置文件："
echo "1) 开发环境 (.env.local)"
echo "2) 生产环境 (.env.production)"
echo "3) 通用配置 (.env)"
echo "4) 全部创建"

read -p "请输入选择 (1-4): " choice

case $choice in
    1)
        echo "📝 创建开发环境配置文件..."
        cat > .env.local << EOF
# 本地开发环境配置
# 这个文件不会被提交到git仓库

# API配置
VITE_API_BASE_URL=http://localhost:8081

# WebSocket配置
VITE_WS_BASE_URL=ws://localhost:8081
EOF
        echo "✅ .env.local 已创建"
        ;;
    2)
        echo "📝 创建生产环境配置文件..."
        cat > .env.production << EOF
# 生产环境配置
# 基于env.prod文件

# API配置
VITE_API_BASE_URL=http://192.168.188.120

# WebSocket配置
VITE_WS_BASE_URL=ws://192.168.188.120
EOF
        echo "✅ .env.production 已创建"
        ;;
    3)
        echo "📝 创建通用配置文件..."
        cat > .env << EOF
# 通用环境配置
# 适用于所有环境

# API配置
VITE_API_BASE_URL=http://localhost:8081

# WebSocket配置
VITE_WS_BASE_URL=ws://localhost:8081
EOF
        echo "✅ .env 已创建"
        ;;
    4)
        echo "📝 创建所有环境配置文件..."
        
        # 开发环境
        cat > .env.local << EOF
# 本地开发环境配置
# 这个文件不会被提交到git仓库

# API配置
VITE_API_BASE_URL=http://localhost:8081

# WebSocket配置
VITE_WS_BASE_URL=ws://localhost:8081
EOF
        
        # 生产环境
        cat > .env.production << EOF
# 生产环境配置
# 基于env.prod文件

# API配置
VITE_API_BASE_URL=http://192.168.188.120

# WebSocket配置
VITE_WS_BASE_URL=ws://192.168.188.120
EOF
        
        # 通用配置
        cat > .env << EOF
# 通用环境配置
# 适用于所有环境

# API配置
VITE_API_BASE_URL=http://localhost:8081

# WebSocket配置
VITE_WS_BASE_URL=ws://localhost:8081
EOF
        
        echo "✅ 所有环境配置文件已创建"
        ;;
    *)
        echo "❌ 无效选择"
        exit 1
        ;;
esac

echo ""
echo "📋 环境变量说明："
echo "- VITE_API_BASE_URL: API服务器地址"
echo "- VITE_WS_BASE_URL: WebSocket服务器地址"
echo ""
echo "🔧 使用方法："
echo "- 开发环境: npm run dev"
echo "- 生产构建: npm run build"
echo "- 生产预览: npm run preview"
echo ""
echo "📖 更多信息请查看 ENVIRONMENT_CONFIG.md" 