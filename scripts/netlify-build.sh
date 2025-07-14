#!/bin/bash

# Netlify构建脚本
set -e

echo "🚀 开始Netlify部署构建..."

# 检查Node.js版本
echo "📦 Node.js版本: $(node --version)"
echo "📦 NPM版本: $(npm --version)"

# 安装依赖
echo "📥 安装项目依赖..."
npm install --legacy-peer-deps

# 创建生产环境变量文件
echo "🔧 配置环境变量..."
if [ -n "$VITE_API" ]; then
  echo "VITE_API=$VITE_API" > .env.production.local
fi

if [ -n "$VITE_API_MUSIC" ]; then
  echo "VITE_API_MUSIC=$VITE_API_MUSIC" >> .env.production.local
fi

# 显示环境变量（调试用）
if [ -f .env.production.local ]; then
  echo "📋 环境变量配置:"
  cat .env.production.local
fi

# 类型检查
echo "🔍 执行类型检查..."
npm run typecheck:web

# 构建项目
echo "🏗️ 开始构建项目..."
npm run build:web

# 检查构建结果
if [ -d "dist" ]; then
  echo "✅ 构建成功！构建文件:"
  ls -la dist/
  
  # 复制必要的静态资源
  if [ -d "resources" ]; then
    echo "📁 复制静态资源..."
    cp -r resources/* dist/
  fi
  
  echo "🎉 Netlify构建完成！"
else
  echo "❌ 构建失败！dist目录不存在"
  exit 1
fi 