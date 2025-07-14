import { useDateFormat } from '@vueuse/core';
import axios from 'axios';

import config from '../../../package.json';

interface GithubReleaseInfo {
  tag_name: string;
  body: string;
  published_at: string;
  html_url: string;
  assets: Array<{
    browser_download_url: string;
    name: string;
    size: number;
  }>;
}

interface ProxyNode {
  url: string;
  server: string;
  ip: string;
  location: string;
  latency: number;
  speed: number;
}

interface ProxyResponse {
  code: number;
  msg: string;
  data: ProxyNode[];
  total: number;
  update_time: string;
}

export interface UpdateResult {
  hasUpdate: boolean;
  latestVersion: string;
  currentVersion: string;
  releaseInfo: {
    tag_name: string;
    body: string;
    html_url: string;
    assets: Array<{
      browser_download_url: string;
      name: string;
    }>;
  } | null;
}

// 缓存相关配置
const CACHE_KEY = 'github_proxy_nodes';
const CACHE_EXPIRE_TIME = 1000 * 60 * 10; // 10分钟过期

// 请求配置
const REQUEST_TIMEOUT = 2000; // 2秒超时

/**
 * 从缓存获取代理节点
 */
const getCachedProxyNodes = (): { nodes: string[]; timestamp: number } | null => {
  const cached = localStorage.getItem(CACHE_KEY);
  if (cached) {
    const { nodes, timestamp } = JSON.parse(cached);
    if (Date.now() - timestamp < CACHE_EXPIRE_TIME) {
      return { nodes, timestamp };
    }
  }
  return null;
};

/**
 * 缓存代理节点
 */
const cacheProxyNodes = (nodes: string[]) => {
  localStorage.setItem(
    CACHE_KEY,
    JSON.stringify({
      nodes,
      timestamp: Date.now()
    })
  );
};

/**
 * 获取代理节点列表
 */
export const getProxyNodes = async (): Promise<string[]> => {
  // 尝试从缓存获取
  const cached = getCachedProxyNodes();
  if (cached) {
    return cached.nodes;
  }

  try {
    // 获取最新代理节点
    const { data } = await axios.get<ProxyResponse>('https://api.akams.cn/github', {
      timeout: REQUEST_TIMEOUT
    });
    if (data.code === 200) {
      // 按速度排序并获取前10个节点
      const nodes = data.data
        .sort((a, b) => b.speed - a.speed)
        .slice(0, 10)
        .map((node) => node.url);

      // 缓存节点
      cacheProxyNodes(nodes);
      return nodes;
    }
  } catch (error) {
    console.error('获取代理节点失败:', error);
  }

  // 使用备用节点
  return [
    'https://gh.lk.cc',
    'https://ghproxy.cn',
    'https://ghproxy.net',
    'https://gitproxy.click',
    'https://github.tbedu.top',
    'https://github.moeyy.xyz'
  ];
};

/**
 * 获取 GitHub 最新发布版本信息
 */
export const getLatestReleaseInfo = async (): Promise<GithubReleaseInfo | null> => {
  try {
    const token = import.meta.env.VITE_GITHUB_TOKEN;
    const headers = {};
    // 构建 API URL 列表
    const apiUrls = [
      // 使用备用API（避免跨域问题）
      'https://music.alger.fun/package.json',
      
      // 使用GitHub Raw API（通常不会有跨域问题）
      'https://raw.githubusercontent.com/algerkong/AlgerMusicPlayer/main/package.json',
      
      // 原始地址（备用）
      'https://api.github.com/repos/algerkong/AlgerMusicPlayer/releases/latest',
      
      // 使用Netlify函数代理（如果部署成功）
      '/.netlify/functions/github-proxy?path=/repos/algerkong/AlgerMusicPlayer/releases/latest',
    ];

    if (token) {
      headers['Authorization'] = `token ${token}`;
    }

    for (const url of apiUrls) {
      try {
        console.log(`尝试访问API: ${url}`);
        const response = await axios.get(url, {
          headers,
          timeout: REQUEST_TIMEOUT
        });
        console.log(`API ${url} 访问成功，状态码:`, response.status);

        if (url.includes('package.json')) {
          console.log('检测到package.json API，处理版本信息');
          // 如果是 package.json，获取对应的 CHANGELOG
          try {
            const changelogUrl = url.replace('package.json', 'CHANGELOG.md');
            const changelogResponse = await axios.get(changelogUrl, {
              timeout: REQUEST_TIMEOUT
            });

            return {
              tag_name: `v${response.data.version}`,
              body: changelogResponse.data,
              html_url: 'https://github.com/algerkong/AlgerMusicPlayer/releases/latest',
              assets: []
            } as unknown as GithubReleaseInfo;
          } catch (changelogError) {
            console.log('获取CHANGELOG失败，使用默认信息');
            // 如果获取CHANGELOG失败，只返回版本信息
            return {
              tag_name: `v${response.data.version}`,
              body: `版本 ${response.data.version} 已发布`,
              html_url: 'https://github.com/algerkong/AlgerMusicPlayer/releases/latest',
              assets: []
            } as unknown as GithubReleaseInfo;
          }
        }
        
        // 如果是Netlify函数代理，直接返回数据
        if (url.includes('/.netlify/functions/github-proxy')) {
          console.log('检测到Netlify函数代理，直接返回数据');
          return response.data;
        }
        
        console.log('使用标准GitHub API响应');
        return response.data;
      } catch (err) {
        console.warn(`尝试访问 ${url} 失败:`, err);
        continue;
      }
    }
    throw new Error('所有 API 地址均无法访问');
  } catch (error) {
    console.error('获取 GitHub Release 信息失败:', error);
    return null;
  }
};

/**
 * 格式化时间
 */
export const formatDate = (dateStr: string): string => {
  return useDateFormat(new Date(dateStr), 'YYYY-MM-DD HH:mm').value;
};

/**
 * 比较两个版本号
 * @param v1 版本号1
 * @param v2 版本号2
 * @returns 如果v1大于v2返回1，如果v1小于v2返回-1，如果相等返回0
 */
export const compareVersions = (v1: string, v2: string): number => {
  const v1Parts = v1.split('.').map(Number);
  const v2Parts = v2.split('.').map(Number);
  
  for (let i = 0; i < Math.max(v1Parts.length, v2Parts.length); i++) {
    const v1Part = v1Parts[i] || 0;
    const v2Part = v2Parts[i] || 0;
    
    if (v1Part > v2Part) return 1;
    if (v1Part < v2Part) return -1;
  }
  
  return 0;
};

/**
 * 检查更新
 */
export const checkUpdate = async (
  currentVersion: string = config.version
): Promise<UpdateResult | null> => {
  try {
    console.log('开始检查更新，当前版本:', currentVersion);
    const releaseInfo = await getLatestReleaseInfo();
    console.log('获取到的releaseInfo:', releaseInfo);
    
    if (!releaseInfo) {
      console.log('未获取到releaseInfo，返回null');
      return null;
    }

    const latestVersion = releaseInfo.tag_name.replace('v', '');
    console.log('处理后的最新版本:', latestVersion);
    console.log('当前版本:', currentVersion);
    
    // 比较版本号，只有当新版本大于当前版本时才返回更新信息
    const comparison = compareVersions(latestVersion, currentVersion);
    console.log('版本比较结果:', comparison);
    
    if (comparison <= 0) {
      console.log('当前版本已是最新或更新，返回null');
      return null;
    }

    return {
      hasUpdate: true,
      latestVersion,
      currentVersion,
      releaseInfo: {
        tag_name: latestVersion,
        body: `## 更新内容\n\n- 版本: ${latestVersion}\n${releaseInfo.body}`,
        html_url: releaseInfo.html_url,
        assets: releaseInfo.assets.map((asset) => ({
          browser_download_url: asset.browser_download_url,
          name: asset.name
        }))
      }
    };
  } catch (error) {
    console.error('检查更新失败:', error);
    return null;
  }
};
