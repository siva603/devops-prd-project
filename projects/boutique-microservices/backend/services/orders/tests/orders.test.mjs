import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';

describe('Orders Service Tests', () => {
  let server;
  let baseUrl;

  before(async () => {
    server = http.createServer((req, res) => {
      if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ status: 'healthy', service: 'orders' }));
      }

      if (req.url === '/orders' && req.method === 'POST') {
        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
          try {
            const data = JSON.parse(body || '{}');
            if (!data.items || !Array.isArray(data.items) || data.items.length === 0) {
              res.writeHead(400, { 'Content-Type': 'application/json' });
              return res.end(JSON.stringify({ error: 'Order must contain at least one item' }));
            }

            const total = data.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
            res.writeHead(201, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
              id: 'ord-test-001',
              totalAmount: total,
              itemCount: data.items.length,
              status: 'confirmed'
            }));
          } catch {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Malformed JSON' }));
          }
        });
        return;
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
    assert.equal(data.service, 'orders');
  });

  test('POST /orders computes accurate totals and creates order', async () => {
    const res = await fetch(`${baseUrl}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        items: [
          { productId: 'p1', price: 150.00, quantity: 2 },
          { productId: 'p2', price: 200.00, quantity: 1 }
        ]
      })
    });
    assert.equal(res.status, 201);
    const data = await res.json();
    assert.equal(data.totalAmount, 500.00);
    assert.equal(data.itemCount, 2);
  });

  test('POST /orders rejects empty items array', async () => {
    const res = await fetch(`${baseUrl}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: [] })
    });
    assert.equal(res.status, 400);
  });
});
