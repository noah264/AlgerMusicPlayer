#!/bin/bash

# AlgerMusicPlayer CentOS 部署脚本
# 适用于 CentOS 7 及以上版本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 系统更新
update_system() {
    log_info "更新系统包..."
    yum update -y
    yum install -y epel-release
}

# 安装基础依赖
install_dependencies() {
    log_info "安装基础依赖..."
    yum groupinstall -y "Development Tools"
    yum install -y wget curl git nginx
    
    # 安装额外的依赖
    yum install -y \
        libX11-devel \
        libXScrnSaver-devel \
        libXrandr-devel \
        libXcursor-devel \
        libXcomposite-devel \
        libXdamage-devel \
        libXext-devel \
        libXfixes-devel \
        libXi-devel \
        libXrender-devel \
        libXtst-devel \
        libXxf86vm-devel \
        alsa-lib-devel \
        atk-devel \
        cairo-devel \
        cups-devel \
        dbus-devel \
        fontconfig-devel \
        freetype-devel \
        gdk-pixbuf2-devel \
        glib2-devel \
        gtk3-devel \
        libdrm-devel \
        libnotify-devel \
        libxcb-devel \
        libxkbcommon-devel \
        mesa-libEGL-devel \
        mesa-libgbm-devel \
        pango-devel \
        pulseaudio-libs-devel \
        xorg-x11-server-Xvfb
}

# 安装Node.js
install_nodejs() {
    log_info "安装Node.js ${NODE_VERSION}..."
    
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
    
    # 验证安装
    node --version
    npm --version
    
    # 安装全局包
    npm install -g pm2
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    # 检查防火墙状态
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        log_success "防火墙配置完成"
    else
        log_warning "防火墙未运行，跳过配置"
    fi
}

# 配置Nginx
configure_nginx() {
    log_info "配置Nginx..."
    
    # 创建Nginx配置
    cat > /etc/nginx/conf.d/alger-music.conf << 'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/alger-music/dist;
    index index.html;

    # 启用gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # SPA路由支持
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API代理（如果需要）
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

    # 测试配置
    nginx -t
    
    # 启动Nginx
    systemctl enable nginx
    systemctl start nginx
}

# 克隆项目
clone_project() {
    log_info "克隆项目..."
    
    PROJECT_DIR="/var/www/alger-music"
    
    # 如果目录存在，先备份
    if [ -d "$PROJECT_DIR" ]; then
        log_warning "项目目录已存在，创建备份..."
        mv "$PROJECT_DIR" "${PROJECT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 克隆项目
    git clone https://github.com/your-username/AlgerMusicPlayer.git "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    log_success "项目克隆完成"
}

# 构建项目
build_project() {
    log_info "构建项目..."
    
    cd /var/www/alger-music
    
    # 安装依赖
    npm install
    
    # 构建项目
    npm run build
    
    # 检查构建结果
    if [ -d "dist" ]; then
        log_success "项目构建成功"
    else
        log_error "项目构建失败，dist目录不存在"
        exit 1
    fi
}

# 配置PM2
configure_pm2() {
    log_info "配置PM2..."
    
    cd /var/www/alger-music
    
    # 创建PM2配置文件
    cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'alger-music',
    script: 'npm',
    args: 'start',
    cwd: '/var/www/alger-music',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
}
EOF

    # 启动应用
    pm2 start ecosystem.config.js
    pm2 save
    pm2 startup
}

# 创建监控脚本
create_monitoring_script() {
    log_info "创建监控脚本..."
    
    cat > /usr/local/bin/alger-music-monitor.sh << 'EOF'
#!/bin/bash

# AlgerMusicPlayer 监控脚本

LOG_FILE="/var/log/alger-music-monitor.log"
PROJECT_DIR="/var/www/alger-music"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# 检查PM2进程
if ! pm2 list | grep -q "alger-music"; then
    log "PM2进程未运行，重启应用"
    cd "$PROJECT_DIR"
    pm2 start ecosystem.config.js
fi

# 检查Nginx
if ! systemctl is-active --quiet nginx; then
    log "Nginx未运行，重启服务"
    systemctl restart nginx
fi

# 检查磁盘空间
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    log "警告：磁盘使用率超过90%"
fi

# 检查内存使用
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.2f", $3*100/$2}')
if (( $(echo "$MEMORY_USAGE > 90" | bc -l) )); then
    log "警告：内存使用率超过90%"
fi
EOF

    chmod +x /usr/local/bin/alger-music-monitor.sh
    
    # 添加到crontab
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/alger-music-monitor.sh") | crontab -
}

# 创建管理脚本
create_management_scripts() {
    log_info "创建管理脚本..."
    
    # 重启脚本
    cat > /usr/local/bin/alger-music-restart.sh << 'EOF'
#!/bin/bash
cd /var/www/alger-music
pm2 restart alger-music
systemctl restart nginx
echo "AlgerMusicPlayer 已重启"
EOF

    # 更新脚本
    cat > /usr/local/bin/alger-music-update.sh << 'EOF'
#!/bin/bash
cd /var/www/alger-music
git pull
npm install
npm run build
pm2 restart alger-music
echo "AlgerMusicPlayer 已更新"
EOF

    # 日志查看脚本
    cat > /usr/local/bin/alger-music-logs.sh << 'EOF'
#!/bin/bash
echo "=== PM2 日志 ==="
pm2 logs alger-music --lines 50
echo ""
echo "=== Nginx 错误日志 ==="
tail -50 /var/log/nginx/error.log
echo ""
echo "=== 监控日志 ==="
tail -50 /var/log/alger-music-monitor.log
EOF

    chmod +x /usr/local/bin/alger-music-*.sh
}

# 设置权限
set_permissions() {
    log_info "设置文件权限..."
    
    # 设置项目目录权限
    chown -R nginx:nginx /var/www/alger-music
    chmod -R 755 /var/www/alger-music
    
    # 设置日志文件权限
    touch /var/log/alger-music-monitor.log
    chown nginx:nginx /var/log/alger-music-monitor.log
}

# 显示部署信息
show_deployment_info() {
    log_success "部署完成！"
    echo ""
    echo "=== 部署信息 ==="
    echo "项目目录: /var/www/alger-music"
    echo "网站地址: http://$(hostname -I | awk '{print $1}')"
    echo "Node.js版本: $(node --version)"
    echo "NPM版本: $(npm --version)"
    echo ""
    echo "=== 管理命令 ==="
    echo "重启应用: /usr/local/bin/alger-music-restart.sh"
    echo "更新应用: /usr/local/bin/alger-music-update.sh"
    echo "查看日志: /usr/local/bin/alger-music-logs.sh"
    echo "PM2管理: pm2 list | pm2 restart alger-music | pm2 stop alger-music"
    echo ""
    echo "=== 服务状态 ==="
    systemctl status nginx --no-pager -l
    echo ""
    pm2 list
}

# 主函数
main() {
    log_info "开始部署 AlgerMusicPlayer..."
    
    # 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root用户运行此脚本"
        exit 1
    fi
    
    check_system_version
    update_system
    install_dependencies
    install_nodejs
    configure_firewall
    configure_nginx
    clone_project
    build_project
    configure_pm2
    create_monitoring_script
    create_management_scripts
    set_permissions
    show_deployment_info
    
    log_success "部署完成！"
}

# 运行主函数
main "$@" 