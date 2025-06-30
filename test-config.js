#!/usr/bin/env node

// 配置测试脚本
console.log('=== LogMonitor 前端配置测试 ===\n');

// 模拟环境变量
const testEnvs = [
  {
    name: '开发环境 - 默认配置',
    env: { DEV: true },
    expected: {
      api: 'http://localhost:8081/api',
      ws: 'ws://localhost:8081/ws'
    }
  },
  {
    name: '开发环境 - 自定义配置',
    env: { 
      DEV: true, 
      VITE_API_BASE_URL: 'http://custom-api:8081',
      VITE_WS_BASE_URL: 'ws://custom-ws:8081'
    },
    expected: {
      api: 'http://custom-api:8081/api',
      ws: 'ws://custom-ws:8081/ws'
    }
  },
  {
    name: '生产环境 - 默认配置',
    env: { DEV: false },
    expected: {
      api: '/api',
      ws: 'ws://localhost/ws' // 模拟window.location.origin
    }
  },
  {
    name: '生产环境 - 自定义配置',
    env: { 
      DEV: false, 
      VITE_API_BASE_URL: 'https://api.example.com',
      VITE_WS_BASE_URL: 'wss://ws.example.com'
    },
    expected: {
      api: 'https://api.example.com/api',
      ws: 'wss://ws.example.com/ws'
    }
  }
];

// 模拟getApiBase函数
function getApiBase(env) {
  if (env.DEV) {
    const baseUrl = env.VITE_API_BASE_URL || 'http://localhost:8081';
    return `${baseUrl}/api`;
  }
  const baseUrl = env.VITE_API_BASE_URL || '';
  return baseUrl ? `${baseUrl}/api` : '/api';
}

// 模拟getWebSocketUrl函数
function getWebSocketUrl(env) {
  if (env.DEV) {
    const baseUrl = env.VITE_WS_BASE_URL || 'ws://localhost:8081';
    return `${baseUrl}/ws`;
  }
  const baseUrl = env.VITE_WS_BASE_URL || 'ws://localhost'; // 模拟window.location.origin
  return `${baseUrl}/ws`;
}

// 运行测试
testEnvs.forEach((test, index) => {
  console.log(`${index + 1}. ${test.name}`);
  
  const actualApi = getApiBase(test.env);
  const actualWs = getWebSocketUrl(test.env);
  
  console.log(`   API URL: ${actualApi}`);
  console.log(`   WS URL:  ${actualWs}`);
  
  const apiMatch = actualApi === test.expected.api;
  const wsMatch = actualWs === test.expected.ws;
  
  if (apiMatch && wsMatch) {
    console.log('   ✅ 配置正确\n');
  } else {
    console.log('   ❌ 配置错误');
    if (!apiMatch) console.log(`      API期望: ${test.expected.api}`);
    if (!wsMatch) console.log(`      WS期望:  ${test.expected.ws}`);
    console.log('');
  }
});

console.log('=== 配置测试完成 ===');
console.log('\n使用说明:');
console.log('1. 开发环境: 创建 .env 文件并设置 VITE_API_BASE_URL 和 VITE_WS_BASE_URL');
console.log('2. 生产环境: 使用部署脚本或nginx代理');
console.log('3. 详细配置请参考 ENVIRONMENT_CONFIG.md'); 