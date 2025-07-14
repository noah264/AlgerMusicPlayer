const axios = require('axios');

exports.handler = async function(event, context) {
  // 设置CORS头
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS'
  };

  // 处理预检请求
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers,
      body: ''
    };
  }

  try {
    const { path, method, body, query } = JSON.parse(event.body || '{}');
    
    // 获取目标API地址（从环境变量或默认值）
    const targetApi = process.env.VITE_API || 'https://your-api-domain.com';
    
    // 构建请求URL
    const url = `${targetApi}${path}`;
    
    // 构建请求配置
    const config = {
      method: method || 'GET',
      url,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'AlgerMusicPlayer/1.0'
      }
    };

    // 添加查询参数
    if (query && Object.keys(query).length > 0) {
      config.params = query;
    }

    // 添加请求体
    if (body && method !== 'GET') {
      config.data = body;
    }

    // 发送请求
    const response = await axios(config);

    return {
      statusCode: response.status,
      headers: {
        ...headers,
        'Content-Type': response.headers['content-type'] || 'application/json'
      },
      body: JSON.stringify(response.data)
    };

  } catch (error) {
    console.error('代理请求错误:', error);
    
    return {
      statusCode: error.response?.status || 500,
      headers,
      body: JSON.stringify({
        error: '代理请求失败',
        message: error.message
      })
    };
  }
}; 