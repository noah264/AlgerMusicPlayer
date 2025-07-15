#!/bin/bash

# AlgerMusicPlayer 快速部署脚本
# 适用于 CentOS 7 及以上版本

set -e

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

# 检查系统版本
check_system_version() {
    log_info "检查系统版本..."
    
    if [ -f /etc/redhat-release ]; then
        cat /etc/redhat-release
    else
        log_error "不支持的操作系统"
        exit 1
    fi
    
    # 检查是否为CentOS 7
    if grep -q "CentOS Linux release 7" /etc/redhat-release; then
        log_warning "检测到CentOS 7，将使用Node.js 16"
        NODE_VERSION="16"
    elif grep -q "CentOS Linux release 8\|CentOS Stream release 8\|CentOS Stream release 9" /etc/redhat-release; then
        log_info "检测到CentOS 8/9，将使用Node.js 18"
        NODE_VERSION="18"
    else
        log_warning "未知的CentOS版本，默认使用Node.js 16"
        NODE_VERSION="16"
    fi
}

# 快速安装Node.js
install_nodejs_quick() {
    log_info "快速安装Node.js ${NODE_VERSION}..."
    
    # 清理旧的Node.js
    yum remove -y nodejs npm 2>/dev/null || true
    
    # 根据系统版本安装对应的Node.js
    if [ "$NODE_VERSION" = "16" ]; then
        # CentOS 7 使用 Node.js 16
        curl -fsSL https://rpm.nodesource.com/setup_16.x | bash -
    else
        # CentOS 8/9 使用 Node.js 18
        curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    fi
    
    yum install -y nodejs
    npm install -g pm2
    
    log_success "Node.js ${NODE_VERSION} 安装完成"
}

# 快速安装Nginx
install_nginx_quick() {
    log_info "安装Nginx..."
    yum install -y nginx
    systemctl enable nginx
    systemctl start nginx
    log_success "Nginx安装完成"
}

# 快速部署项目
deploy_project_quick() {
    log_info "快速部署项目..."
    
    PROJECT_DIR="/var/www/alger-music"
    
    # 创建项目目录
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # 如果目录不为空，先备份
    if [ "$(ls -A)" ]; then
        log_warning "项目目录不为空，创建备份..."
        mv "$PROJECT_DIR" "${PROJECT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$PROJECT_DIR"
        cd "$PROJECT_DIR"
    fi
    
    # 克隆项目（需要替换为实际的Git仓库地址）
    log_info "请确保已配置正确的Git仓库地址"
    # git clone https://github.com/your-username/AlgerMusicPlayer.git .
    
    # 安装依赖并构建
    npm install
    npm run build
    
    # 配置Nginx
    cat > /etc/nginx/conf.d/alger-music.conf << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/alger-music/dist;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

    nginx -t && systemctl reload nginx
    
    log_success "项目快速部署完成"
}

# 显示快速部署信息
show_quick_info() {
    log_success "快速部署完成！"
    echo ""
    echo "=== 快速部署信息 ==="
    echo "项目目录: /var/www/alger-music"
    echo "网站地址: http://$(hostname -I | awk '{print $1}')"
    echo "Node.js版本: $(node --version)"
    echo ""
    echo "=== 下一步操作 ==="
    echo "1. 配置Git仓库地址"
    echo "2. 运行完整部署脚本: bash deploy-centos.sh"
    echo "3. 或手动完成剩余配置"
}

# 主函数
main() {
    log_info "开始快速部署 AlgerMusicPlayer..."
    
    # 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root用户运行此脚本"
        exit 1
    fi
    
    check_system_version
    install_nodejs_quick
    install_nginx_quick
    deploy_project_quick
    show_quick_info
    
    log_success "快速部署完成！"
}

# 运行主函数
main "$@" 