import { Request, Response, NextFunction } from 'express';

interface RateLimitRecord {
  timestamps: number[];
}

const ipStore = new Map<string, RateLimitRecord>();

// Clean up stale IP records every 5 minutes to prevent memory leak
setInterval(() => {
  const now = Date.now();
  for (const [ip, record] of ipStore.entries()) {
    record.timestamps = record.timestamps.filter(ts => now - ts < 300000);
    if (record.timestamps.length === 0) {
      ipStore.delete(ip);
    }
  }
}, 300000);

export interface RateLimitOptions {
  windowMs?: number; // Time window in milliseconds (default: 60,000ms = 1 min)
  max?: number;      // Max allowed requests in the window (default: 100)
  message?: string;
  skipFailedRequests?: boolean;
}

export function createRateLimiter(options: RateLimitOptions = {}) {
  const windowMs = options.windowMs || Number(process.env.RATE_LIMIT_WINDOW_MS) || 60000;
  const max = options.max || Number(process.env.RATE_LIMIT_MAX_REQUESTS) || 100;
  const message = options.message || 'Too many requests, please try again later.';

  return (req: Request, res: Response, next: NextFunction) => {
    // Get client IP address
    const clientIp = (
      (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ||
      req.socket.remoteAddress ||
      'unknown'
    );

    const now = Date.now();
    const record = ipStore.get(clientIp) || { timestamps: [] };

    // Filter out timestamps outside the active window
    record.timestamps = record.timestamps.filter(timestamp => now - timestamp < windowMs);

    const remaining = Math.max(0, max - record.timestamps.length);
    const resetTime = Math.ceil((windowMs - (now - (record.timestamps[0] || now))) / 1000);

    // Standard rate limit headers
    res.setHeader('X-RateLimit-Limit', max);
    res.setHeader('X-RateLimit-Remaining', remaining);
    res.setHeader('X-RateLimit-Reset', resetTime);

    if (record.timestamps.length >= max) {
      res.setHeader('Retry-After', resetTime);
      return res.status(429).json({
        error: 'Too Many Requests',
        message,
        retryAfterSeconds: resetTime,
        limit: max
      });
    }

    record.timestamps.push(now);
    ipStore.set(clientIp, record);
    next();
  };
}

// Preset limiters for production
export const generalLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 100,
  message: 'General API rate limit exceeded (100 req/min).'
});

export const authLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 20,
  message: 'Authentication rate limit exceeded (20 req/min). Please wait before trying again.'
});

export const strictTestLimiter = createRateLimiter({
  windowMs: 10 * 1000,
  max: 5,
  message: 'Rate limit test threshold exceeded (5 req/10s).'
});
