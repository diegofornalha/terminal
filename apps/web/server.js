const { createServer } = require('http');
const { parse } = require('url');
const next = require('next');
const { createProxyMiddleware } = require('http-proxy-middleware');

const dev = process.env.NODE_ENV !== 'production';
const hostname = '0.0.0.0';
const port = parseInt(process.env.PORT || '3005', 10);

console.log('Starting server...');
console.log('Dev mode:', dev);
console.log('Port:', port);

const app = next({ dev, hostname, port });
const handle = app.getRequestHandler();

app.prepare().then(() => {
  console.log('Next.js app prepared');
  
  const server = createServer((req, res) => {
    const parsedUrl = parse(req.url, true);
    handle(req, res, parsedUrl);
  });

  // WebSocket proxy configuration
  const apiBase = process.env.NEXT_PUBLIC_API_BASE || 'http://api:8000';
  console.log('API base for proxy:', apiBase);
  
  const wsProxy = createProxyMiddleware('/ws', {
    target: apiBase,
    ws: true,
    changeOrigin: true,
    logLevel: 'debug',
  });

  // Handle WebSocket upgrade
  server.on('upgrade', (req, socket, head) => {
    console.log('WebSocket upgrade request:', req.url);
    if (req.url && req.url.startsWith('/ws/')) {
      wsProxy.upgrade(req, socket, head);
    }
  });

  server.listen(port, hostname, (err) => {
    if (err) throw err;
    console.log(`> Ready on http://${hostname}:${port}`);
  });
}).catch((err) => {
  console.error('Error starting server:', err);
  process.exit(1);
});