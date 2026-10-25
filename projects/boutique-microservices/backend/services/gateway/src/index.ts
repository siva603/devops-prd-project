import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { createProxyMiddleware } from 'http-proxy-middleware';
import dotenv from 'dotenv';
import { metricsMiddleware, setupMetrics } from './metrics';
import { generalLimiter, authLimiter, strictTestLimiter } from './middleware/rateLimiter';

dotenv.config();

const app = express();
const PORT: number = Number(process.env.GATEWAY_PORT || process.env.PORT) || 3001;

// Security and standard middlewares
app.use(helmet());
app.use(cors());

// Setup Prometheus metrics
setupMetrics(app, { serviceName: 'gateway', serviceVersion: '1.0.0' });
app.use(metricsMiddleware);

// Health check endpoint for Kubernetes liveness & readiness probes
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    service: 'gateway',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Dedicated endpoint to test rate limiting behavior (5 req / 10s)
app.get('/api/test-ratelimit', strictTestLimiter, (req, res) => {
  res.status(200).json({
    message: 'Rate limit test passed. You are within the allowed threshold.'
  });
});

// Microservice backend destinations with robust fallback logic
const services = {
  auth: process.env.AUTH_SERVICE_URL || 'http://localhost:3002',
  products: process.env.PRODUCTS_SERVICE_URL || 'http://localhost:3003',
  orders: process.env.ORDERS_SERVICE_URL || process.env.ORDER_SERVICE_URL || 'http://localhost:3005',
  users: process.env.USERS_SERVICE_URL || process.env.USER_SERVICE_URL || 'http://localhost:3006',
};

// Route-specific rate limiters
app.use('/api/auth', authLimiter, createProxyMiddleware({
  target: services.auth,
  changeOrigin: true,
  pathRewrite: { '^/api/auth': '' },
}));

app.use('/api/products', generalLimiter, createProxyMiddleware({
  target: services.products,
  changeOrigin: true,
  pathRewrite: { '^/api/products': '' },
}));

app.use('/api/orders', generalLimiter, createProxyMiddleware({
  target: services.orders,
  changeOrigin: true,
  pathRewrite: { '^/api/orders': '' },
}));

app.use('/api/users', generalLimiter, createProxyMiddleware({
  target: services.users,
  changeOrigin: true,
  pathRewrite: { '^/api/users': '' },
}));

// Fallback 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Service or endpoint not found' });
});

// Centralized error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('API Gateway error:', err.stack);
  res.status(500).json({ error: 'Internal gateway error', message: err.message });
});

// Only start listening if not running in test mode
if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`API Gateway running on port ${PORT}`);
    console.log(`Proxying to services:`, services);
  });
}

export default app;
