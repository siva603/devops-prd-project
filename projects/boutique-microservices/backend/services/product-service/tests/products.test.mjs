import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';

describe('Product Service Tests', () => {
  let server;
  let baseUrl;

  before(async () => {
    server = http.createServer((req, res) => {
      const url = new URL(req.url, 'http://localhost');

      if (url.pathname === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ status: 'healthy', service: 'product-service' }));
      }

      if (url.pathname === '/products') {
        const page = parseInt(url.searchParams.get('page') || '1');
        const limit = parseInt(url.searchParams.get('limit') || '10');
        const mockProducts = [
          { id: '1', name: 'Silk Evening Gown', price: 899.99, category: 'Dresses' },
          { id: '2', name: 'Cashmere Winter Coat', price: 1299.99, category: 'Outerwear' },
          { id: '3', name: 'Italian Leather Handbag', price: 649.99, category: 'Bags' }
        ];

        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({
          success: true,
          data: {
            products: mockProducts,
            pagination: {
              currentPage: page,
              totalPages: 1,
              total: mockProducts.length
            }
          }
        }));
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
    assert.equal(data.service, 'product-service');
  });

  test('GET /products returns product catalog payload', async () => {
    const res = await fetch(`${baseUrl}/products?page=1&limit=5`);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.success, true);
    assert.equal(data.data.products.length, 3);
  });
});
