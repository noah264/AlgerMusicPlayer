#!/bin/bash

# AlgerMusicPlayer CentOS 部署脚本
# 作者: Alger
# 版本: 1.0

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 配置变量
PROJECT_NAME="AlgerMusicPlayer"
PROJECT_DIR="/var/www/alger-music"
GIT_REPO="https://github.com/algerkong/AlgerMusicPlayer.git"
NODE_VERSION="18"
PM2_APP_NAME="alger-music"

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "请不要使用root用户运行此脚本"
        exit 1
    fi
}

# 检查系统要求
check_system() {
    log_step "检查系统要求..."
    
    # 检查操作系统
    if [[ ! -f /etc/redhat-release ]]; then
        log_error "此脚本仅支持CentOS/RHEL系统"
        exit 1
    fi
    
    # 检查内存
    MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ $MEMORY -lt 2048 ]; then
        log_warn "系统内存不足2GB，可能影响构建性能"
    fi
    
    # 检查磁盘空间
    DISK_SPACE=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [ $DISK_SPACE -lt 10 ]; then
        log_error "磁盘空间不足10GB"
        exit 1
    fi
    
    log_info "系统检查通过"
}

# 安装系统依赖
install_system_deps() {
    log_step "安装系统依赖..."
    
    # 更新系统
    sudo yum update -y
    
    # 安装基础工具
    sudo yum install -y \
        curl \
        wget \
        git \
        unzip \
        nginx \
        firewalld \
        epel-release
    
    # 启动并启用防火墙
    sudo systemctl start firewalld
    sudo systemctl enable firewalld
    
    # 配置防火墙
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --permanent --add-port=3000/tcp
    sudo firewall-cmd --reload
    
    log_info "系统依赖安装完成"
}

# 安装Node.js
install_nodejs() {
    log_step "安装Node.js ${NODE_VERSION}..."
    
    # 安装NodeSource仓库
    curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | sudo bash -
    
    # 安装Node.js
    sudo yum install -y nodejs
    
    # 验证安装
    NODE_VERSION_INSTALLED=$(node --version)
    NPM_VERSION_INSTALLED=$(npm --version)
    
    log_info "Node.js ${NODE_VERSION_INSTALLED} 安装完成"
    log_info "npm ${NPM_VERSION_INSTALLED} 安装完成"
}

# 安装PM2
install_pm2() {
    log_step "安装PM2..."
    
    sudo npm install -g pm2
    
    # 设置PM2开机自启
    pm2 startup systemd
    sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp $HOME
    
    log_info "PM2安装完成"
}

# 创建项目目录
create_project_dir() {
    log_step "创建项目目录..."
    
    sudo mkdir -p $PROJECT_DIR
    sudo chown $USER:$USER $PROJECT_DIR
    
    log_info "项目目录创建完成: $PROJECT_DIR"
}

# 克隆项目
clone_project() {
    log_step "克隆项目代码..."
    
    cd $PROJECT_DIR
    
    if [ -d ".git" ]; then
        log_info "项目已存在，更新代码..."
        git pull origin main
    else
        log_info "克隆新项目..."
        git clone $GIT_REPO .
    fi
    
    log_info "项目代码获取完成"
}

# 安装项目依赖
install_project_deps() {
    log_step "安装项目依赖..."
    
    cd $PROJECT_DIR
    
    # 安装依赖
    npm install
    
    log_info "项目依赖安装完成"
}

# 构建项目
build_project() {
    log_step "构建项目..."
    
    cd $PROJECT_DIR
    
    # 构建Web版本
    npm run build:web
    
    # 检查构建结果
    if [ ! -d "dist" ]; then
        log_error "构建失败，dist目录不存在"
        exit 1
    fi
    
    log_info "项目构建完成"
}

# 配置Nginx
configure_nginx() {
    log_step "配置Nginx..."
    
    # 创建Nginx配置文件
    sudo tee /etc/nginx/conf.d/alger-music.conf > /dev/null <<EOF
server {
    listen 80;
    server_name _;
    root $PROJECT_DIR/dist;
    index index.html;
    
    # 启用gzip压缩
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
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # API代理
    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Netlify函数代理
    location /.netlify/functions/ {
        proxy_pass http://localhost:3000/.netlify/functions/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # SPA路由支持
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF
    
    # 测试Nginx配置
    sudo nginx -t
    
    # 重启Nginx
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    
    log_info "Nginx配置完成"
}

# 创建PM2配置文件
create_pm2_config() {
    log_step "创建PM2配置..."
    
    cd $PROJECT_DIR
    
    # 创建PM2配置文件
    cat > ecosystem.config.js <<EOF
module.exports = {
  apps: [{
    name: '$PM2_APP_NAME',
    script: 'npm',
    args: 'run dev:web',
    cwd: '$PROJECT_DIR',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
EOF
    
    # 创建日志目录
    mkdir -p logs
    
    log_info "PM2配置创建完成"
}

# 启动应用
start_application() {
    log_step "启动应用..."
    
    cd $PROJECT_DIR
    
    # 停止现有进程
    pm2 stop $PM2_APP_NAME 2>/dev/null || true
    pm2 delete $PM2_APP_NAME 2>/dev/null || true
    
    # 启动应用
    pm2 start ecosystem.config.js
    
    # 保存PM2配置
    pm2 save
    
    log_info "应用启动完成"
}

# 创建部署脚本
create_deploy_script() {
    log_step "创建快速部署脚本..."
    
    cat > $PROJECT_DIR/deploy.sh <<EOF
#!/bin/bash

cd $PROJECT_DIR

# 拉取最新代码
git pull origin main

# 安装依赖
npm install

# 构建项目
npm run build:web

# 重启应用
pm2 restart $PM2_APP_NAME

echo "部署完成！"
EOF
    
    chmod +x $PROJECT_DIR/deploy.sh
    
    log_info "快速部署脚本创建完成: $PROJECT_DIR/deploy.sh"
}

# 创建监控脚本
create_monitor_script() {
    log_step "创建监控脚本..."
    
    cat > $PROJECT_DIR/monitor.sh <<EOF
#!/bin/bash

echo "=== AlgerMusicPlayer 系统监控 ==="
echo "时间: \$(date)"
echo ""

echo "=== 系统资源 ==="
echo "CPU使用率: \$(top -bn1 | grep "Cpu(s)" | awk '{print \$2}' | cut -d'%' -f1)%"
echo "内存使用率: \$(free | grep Mem | awk '{printf("%.2f%%", \$3/\$2 * 100.0)}')"
echo "磁盘使用率: \$(df -h / | awk 'NR==2{print \$5}')"
echo ""

echo "=== 应用状态 ==="
pm2 status
echo ""

echo "=== Nginx状态 ==="
systemctl status nginx --no-pager -l
echo ""

echo "=== 最近日志 ==="
tail -n 20 $PROJECT_DIR/logs/combined.log
EOF
    
    chmod +x $PROJECT_DIR/monitor.sh
    
    log_info "监控脚本创建完成: $PROJECT_DIR/monitor.sh"
}

# 设置定时任务
setup_cron() {
    log_step "设置定时任务..."
    
    # 创建日志轮转脚本
    cat > $PROJECT_DIR/rotate-logs.sh <<EOF
#!/bin/bash

# 轮转日志文件
find $PROJECT_DIR/logs -name "*.log" -size +10M -exec truncate -s 5M {} \;

# 清理旧日志
find $PROJECT_DIR/logs -name "*.log" -mtime +7 -delete
EOF
    
    chmod +x $PROJECT_DIR/rotate-logs.sh
    
    # 添加到crontab
    (crontab -l 2>/dev/null; echo "0 2 * * * $PROJECT_DIR/rotate-logs.sh") | crontab -
    
    log_info "定时任务设置完成"
}

# 显示部署信息
show_deployment_info() {
    log_step "部署完成！"
    echo ""
    echo "=== 部署信息 ==="
    echo "项目目录: $PROJECT_DIR"
    echo "访问地址: http://$(curl -s ifconfig.me)"
    echo "PM2应用名: $PM2_APP_NAME"
    echo ""
    echo "=== 常用命令 ==="
    echo "查看应用状态: pm2 status"
    echo "查看日志: pm2 logs $PM2_APP_NAME"
    echo "重启应用: pm2 restart $PM2_APP_NAME"
    echo "停止应用: pm2 stop $PM2_APP_NAME"
    echo "快速部署: $PROJECT_DIR/deploy.sh"
    echo "系统监控: $PROJECT_DIR/monitor.sh"
    echo ""
    echo "=== 日志文件 ==="
    echo "应用日志: $PROJECT_DIR/logs/"
    echo "Nginx日志: /var/log/nginx/"
    echo ""
}

# 主函数
main() {
    echo "=================================="
    echo "AlgerMusicPlayer CentOS 部署脚本"
    echo "=================================="
    echo ""
    
    check_root
    check_system
    install_system_deps
    install_nodejs
    install_pm2
    create_project_dir
    clone_project
    install_project_deps
    build_project
    configure_nginx
    create_pm2_config
    start_application
    create_deploy_script
    create_monitor_script
    setup_cron
    show_deployment_info
    
    log_info "部署完成！"
}

# 运行主函数
main "$@" 