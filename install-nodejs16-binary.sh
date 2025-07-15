#!/bin/bash

# Node.js 16 二进制安装脚本
# 避免包管理器版本冲突问题

set -e

echo "=== 开始安装Node.js 16（二进制方式）==="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "错误：请使用root用户运行此脚本"
    exit 1
fi

echo "1. 检查系统架构..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    NODE_ARCH="x64"
elif [ "$ARCH" = "aarch64" ]; then
    NODE_ARCH="arm64"
else
    echo "错误：不支持的架构: $ARCH"
    exit 1
fi

echo "架构: $ARCH ($NODE_ARCH)"

echo ""
echo "2. 清理旧的Node.js安装..."
# 卸载包管理器安装的Node.js
yum remove -y nodejs npm 2>/dev/null || true

# 清理二进制安装的Node.js
rm -rf /usr/local/node
rm -rf /opt/node
rm -f /usr/local/bin/node
rm -f /usr/local/bin/npm
rm -f /usr/local/bin/npx

echo ""
echo "3. 下载Node.js 16二进制包..."
NODE_VERSION="16.20.2"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
NODE_TAR="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"

cd /tmp
wget -O "$NODE_TAR" "$NODE_URL"

echo ""
echo "4. 解压并安装Node.js..."
tar -xf "$NODE_TAR"
sudo mv "node-v${NODE_VERSION}-linux-${NODE_ARCH}" /usr/local/node

echo ""
echo "5. 创建符号链接..."
ln -sf /usr/local/node/bin/node /usr/local/bin/node
ln -sf /usr/local/node/bin/npm /usr/local/bin/npm
ln -sf /usr/local/node/bin/npx /usr/local/bin/npx

echo ""
echo "6. 验证安装..."
NODE_VERSION_INSTALLED=$(node --version 2>/dev/null || echo "未安装")
NPM_VERSION_INSTALLED=$(npm --version 2>/dev/null || echo "未安装")

echo "Node.js版本: $NODE_VERSION_INSTALLED"
echo "NPM版本: $NPM_VERSION_INSTALLED"

if [[ "$NODE_VERSION_INSTALLED" == v16* ]]; then
    echo "✅ Node.js 16 安装成功！"
    
    echo ""
    echo "7. 安装PM2..."
    npm install -g pm2
    
    echo ""
    echo "8. 清理下载文件..."
    rm -f "/tmp/$NODE_TAR"
    
    echo ""
    echo "=== 安装完成 ==="
    echo "Node.js版本: $(node --version)"
    echo "NPM版本: $(npm --version)"
    echo "PM2版本: $(pm2 --version 2>/dev/null || echo '未安装')"
    echo "安装路径: /usr/local/node"
    
    echo ""
    echo "现在可以运行部署脚本了："
    echo "bash deploy-centos7.sh"
else
    echo "❌ Node.js 16 安装失败！"
    echo "当前版本: $NODE_VERSION_INSTALLED"
    echo "请检查错误信息并重试"
    exit 1
fi 