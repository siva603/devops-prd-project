import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';

describe('User Service Tests', () => {
  let server;
  let baseUrl;

  before(async () => {
    server = http.createServer((req, res) => {
      if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ status: 'healthy', service: 'user-service' }));
      }

      if (req.url === '/profile') {
        const auth = req.headers.authorization;
        if (!auth) {
          res.writeHead(401, { 'Content-Type': 'application/json' });
          return res.end(JSON.stringify({ error: 'Unauthorized' }));
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({
          id: 'usr-100',
          email: 'customer@boutique.com',
          firstName: 'Jane',
          lastName: 'Doe'
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
    assert.equal(data.service, 'user-service');
  });

  test('GET /profile rejects unauthorized requests without token', async () => {
    const res = await fetch(`${baseUrl}/profile`);
    assert.equal(res.status, 401);
  });

  test('GET /profile returns user profile when bearer token present', async () => {
    const res = await fetch(`${baseUrl}/profile`, {
      headers: { Authorization: 'Bearer valid-jwt-token' }
    });
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.email, 'customer@boutique.com');
  });
});
