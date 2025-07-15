#!/bin/bash

# AlgerMusicPlayer 快速部署脚本
# 用于更新已部署的应用

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 配置
PROJECT_DIR="/var/www/alger-music"
PM2_APP_NAME="alger-music"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查项目目录
if [ ! -d "$PROJECT_DIR" ]; then
    log_error "项目目录不存在: $PROJECT_DIR"
    log_error "请先运行完整的部署脚本: deploy-centos.sh"
    exit 1
fi

cd "$PROJECT_DIR"

log_info "开始快速部署..."

# 备份当前版本
log_info "备份当前版本..."
if [ -d "dist" ]; then
    cp -r dist dist.backup.$(date +%Y%m%d_%H%M%S)
fi

# 拉取最新代码
log_info "拉取最新代码..."
git fetch origin
git reset --hard origin/main

# 安装依赖
log_info "安装依赖..."
npm install

# 构建项目
log_info "构建项目..."
npm run build:web

# 检查构建结果
if [ ! -d "dist" ]; then
    log_error "构建失败，恢复备份..."
    if [ -d "dist.backup"* ]; then
        rm -rf dist
        cp -r dist.backup.* dist
    fi
    exit 1
fi

# 重启应用
log_info "重启应用..."
pm2 restart "$PM2_APP_NAME"

# 清理备份
log_info "清理旧备份..."
find . -name "dist.backup.*" -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

log_info "快速部署完成！"
log_info "访问地址: http://$(curl -s ifconfig.me 2>/dev/null || echo 'localhost')" 