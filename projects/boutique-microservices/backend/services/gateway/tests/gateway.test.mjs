import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';

// Self-contained sliding-window rate limiter for unit testing
function createTestLimiter({ windowMs, max }) {
  const store = new Map();
  return (req, res, next) => {
    const ip = req.socket.remoteAddress || '127.0.0.1';
    const now = Date.now();
    const record = store.get(ip) || { timestamps: [] };
    record.timestamps = record.timestamps.filter(t => now - t < windowMs);

    const remaining = Math.max(0, max - record.timestamps.length);
    res.setHeader('X-RateLimit-Limit', max);
    res.setHeader('X-RateLimit-Remaining', remaining);

    if (record.timestamps.length >= max) {
      res.setHeader('Retry-After', Math.ceil(windowMs / 1000));
      res.writeHead(429, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({
        error: 'Too Many Requests',
        message: 'Rate limit exceeded'
      }));
    }

    record.timestamps.push(now);
    store.set(ip, record);
    next();
  };
}

describe('Gateway Service Tests', () => {
  let server;
  let baseUrl;

  before(async () => {
    const limiter = createTestLimiter({ windowMs: 5000, max: 3 });

    server = http.createServer((req, res) => {
      if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ status: 'healthy', service: 'gateway', uptime: process.uptime() }));
      }

      if (req.url === '/api/test-ratelimit') {
        return limiter(req, res, () => {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ message: 'Request within limit' }));
        });
      }

      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Not Found' }));
    });

    await new Promise((resolve) => server.listen(0, resolve));
    const port = server.address().port;
    baseUrl = `http://127.0.0.1:${port}`;
  });

  after(() => {
    if (server) server.close();
  });

  test('GET /health returns 200 and healthy status', async () => {
    const res = await fetch(`${baseUrl}/health`);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.status, 'healthy');
    assert.equal(data.service, 'gateway');
    assert.ok(typeof data.uptime === 'number');
  });

  test('Rate Limiter allows initial requests and blocks 4th request with HTTP 429', async () => {
    // Threshold is 3 requests
    for (let i = 0; i < 3; i++) {
      const res = await fetch(`${baseUrl}/api/test-ratelimit`);
      assert.equal(res.status, 200, `Request ${i + 1} must succeed`);
      assert.equal(res.headers.get('x-ratelimit-limit'), '3');
    }

    // 4th request should be rejected with 429
    const blockedRes = await fetch(`${baseUrl}/api/test-ratelimit`);
    assert.equal(blockedRes.status, 429, '4th request must return 429');
    assert.ok(blockedRes.headers.get('retry-after'), 'Must contain Retry-After header');
    const body = await blockedRes.json();
    assert.equal(body.error, 'Too Many Requests');
  });

  test('Non-existent route returns 404', async () => {
    const res = await fetch(`${baseUrl}/undefined-route`);
    assert.equal(res.status, 404);
  });
});
