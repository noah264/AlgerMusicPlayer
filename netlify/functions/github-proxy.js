const axios = require('axios');

exports.handler = async function(event, context) {
  console.log('GitHub代理函数被调用:', {
    method: event.httpMethod,
    path: event.path,
    query: event.queryStringParameters,
    headers: event.headers
  });

  // 设置CORS头
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS'
  };

  // 处理预检请求
  if (event.httpMethod === 'OPTIONS') {
    console.log('处理OPTIONS预检请求');
    return {
      statusCode: 200,
      headers,
      body: ''
    };
  }

  try {
    // 从查询参数获取路径
    const { path } = event.queryStringParameters || {};
    
    console.log('请求路径:', path);
    
    if (!path) {
      console.log('缺少path参数');
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: '缺少path参数'
        })
      };
    }

    // 构建GitHub API URL
    const githubApiUrl = `https://api.github.com${path}`;
    console.log('GitHub API URL:', githubApiUrl);
    
    // 构建请求配置
    const config = {
      method: 'GET',
      url: githubApiUrl,
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'AlgerMusicPlayer/1.0'
      },
      timeout: 10000 // 10秒超时
    };

    // 如果有GitHub Token，添加到请求头
    const githubToken = process.env.GITHUB_TOKEN;
    if (githubToken) {
      config.headers['Authorization'] = `token ${githubToken}`;
    }

    // 发送请求到GitHub API
    console.log('发送请求到GitHub API...');
    const response = await axios(config);
    console.log('GitHub API响应状态:', response.status);

    return {
      statusCode: response.status,
      headers: {
        ...headers,
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=300' // 缓存5分钟
      },
      body: JSON.stringify(response.data)
    };

  } catch (error) {
    console.error('GitHub API代理错误:', error);
    
    return {
      statusCode: error.response?.status || 500,
      headers,
      body: JSON.stringify({
        error: 'GitHub API请求失败',
        message: error.message,
        status: error.response?.status
      })
    };
  }
}; 