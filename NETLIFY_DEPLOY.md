# AlgerMusicPlayer Netlify 部署指南

## 概述

本指南将帮助您将AlgerMusicPlayer部署到Netlify平台。

## 部署步骤

### 1. 准备环境变量

在Netlify控制台中设置以下环境变量：

- `VITE_API`: 您的音乐API服务器地址
- `VITE_API_MUSIC`: 音乐解锁API地址

### 2. 连接Git仓库

1. 登录Netlify控制台
2. 点击"New site from Git"
3. 选择您的Git提供商（GitHub、GitLab等）
4. 选择AlgerMusicPlayer仓库
5. 配置部署设置：
   - Build command: `npm run build:web`
   - Publish directory: `dist`

### 3. 自动部署配置

项目已包含`netlify.toml`配置文件，会自动：
- 使用Node.js 18
- 安装依赖并构建项目
- 配置SPA路由重定向
- 设置安全头
- 配置静态资源缓存

### 4. 自定义域名（可选）

1. 在Netlify控制台进入站点设置
2. 点击"Domain management"
3. 添加您的自定义域名
4. 配置DNS记录

## 文件结构

```
AlgerMusicPlayer/
├── netlify.toml              # Netlify配置文件
├── vite.netlify.config.ts    # Netlify专用Vite配置
├── scripts/
│   └── netlify-build.sh      # 构建脚本
├── netlify/
│   └── functions/
│       └── proxy.js          # API代理函数
└── NETLIFY_DEPLOY.md         # 本文件
```

## 构建过程

1. **安装依赖**: 使用`--legacy-peer-deps`标志
2. **环境变量**: 自动创建`.env.production.local`
3. **类型检查**: 执行TypeScript类型检查
4. **构建**: 使用优化的Vite配置构建
5. **资源复制**: 复制静态资源到dist目录

## 性能优化

- **代码分割**: 自动分割vendor、UI和工具库
- **压缩**: 生成gzip和brotli压缩文件
- **缓存**: 静态资源设置长期缓存
- **CDN**: 利用Netlify的全球CDN

## 故障排除

### 构建失败

1. 检查Node.js版本（需要18+）
2. 确认环境变量设置正确
3. 查看构建日志中的错误信息

### API请求失败

1. 确认`VITE_API`环境变量设置正确
2. 检查API服务器是否可访问
3. 查看浏览器控制台错误信息

### 路由问题

1. 确认`netlify.toml`中的重定向规则正确
2. 检查Vue Router的history模式配置

## 本地测试

```bash
# 安装依赖
npm install

# 本地构建测试
npm run build:web

# 预览构建结果
npx serve dist
```

## 更新部署

每次推送到主分支时，Netlify会自动触发新的部署。

## 支持

如果遇到部署问题，请：
1. 检查Netlify构建日志
2. 确认环境变量配置
3. 查看项目GitHub Issues

---

**注意**: 确保您的API服务器支持CORS，并且可以从Netlify的域名访问。 