const rateLimit = require('express-rate-limit');

// Strict rate limiting for auth endpoints (brute-force protection)
exports.authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Max 10 attempts per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many login attempts. Please try again in 15 minutes.'
  }
});

// SMS sending rate limiting per user
exports.smsLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30, // Max 30 SMS per minute
  keyGenerator: (req) => req.user?.companyId || req.ip, // Rate limit per company
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'SMS rate limit exceeded. Maximum 30 SMS per minute.'
  }
});
