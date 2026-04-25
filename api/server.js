const http = require('http');
const os = require('os');

const PORT = process.env.PORT || 3000;
const SERVICE_NAME = process.env.SERVICE_NAME || 'api';

// Simulate some in-memory data
const products = [
  { id: 1, name: 'Laptop Pro X', price: 1299.99, stock: 42 },
  { id: 2, name: 'Monitor UltraWide', price: 499.99, stock: 15 },
  { id: 3, name: 'Teclado Mecánico', price: 89.99, stock: 128 },
  { id: 4, name: 'Mouse Ergonómico', price: 59.99, stock: 73 },
  { id: 5, name: 'Webcam 4K', price: 149.99, stock: 31 }
];

let requestCount = 0;
const startTime = Date.now();

function getNodeInfo() {
  return {
    hostname: os.hostname(),
    platform: os.platform(),
    uptime_seconds: Math.floor((Date.now() - startTime) / 1000),
    memory_mb: Math.round(process.memoryUsage().rss / 1024 / 1024),
    request_count: ++requestCount,
    service: SERVICE_NAME,
    pid: process.pid,
    container_id: os.hostname().substring(0, 12),
  };
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('X-Served-By', os.hostname());

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const nodeInfo = getNodeInfo();

  // Log request
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${url.pathname} - Container: ${nodeInfo.container_id}`);

  if (url.pathname === '/api/health') {
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'healthy',
      ...nodeInfo,
      timestamp: new Date(),
    }, null, 2));
    return;
  }

  if (url.pathname === '/api/products') {
    res.writeHead(200);
    res.end(JSON.stringify({
      products,
      meta: {
        total: products.length,
        served_by: nodeInfo,
        timestamp: new Date().toISOString(),
      }
    }, null, 2));
    return;
  }

  if (url.pathname.startsWith('/api/products/')) {
    const id = parseInt(url.pathname.split('/')[3]);
    const product = products.find(p => p.id === id);
    if (product) {
      res.writeHead(200);
      res.end(JSON.stringify({ product, served_by: nodeInfo }, null, 2));
    } else {
      res.writeHead(404);
      res.end(JSON.stringify({ error: 'Product not found', served_by: nodeInfo }, null, 2));
    }
    return;
  }

  if (url.pathname === '/api/stress') {
    // CPU stress for demo purposes
    let sum = 0;
    for (let i = 0; i < 1000000; i++) sum += Math.sqrt(i);
    res.writeHead(200);
    res.end(JSON.stringify({ result: sum, served_by: nodeInfo }, null, 2));
    return;
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: 'Route not found', served_by: nodeInfo }, null, 2));
});

server.listen(PORT, () => {
  console.log(`✅ API Server running on port ${PORT}`);
  console.log(`   Container: ${os.hostname()}`);
  console.log(`   Service:   ${SERVICE_NAME}`);
  console.log(`   PID:       ${process.pid}`);
});

process.on('SIGTERM', () => {
  console.log('⚠️  SIGTERM received — graceful shutdown...');
  server.close(() => {
    console.log('👋 Server closed');
    process.exit(0);
  });
});
