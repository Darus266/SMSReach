require('dotenv').config();

module.exports = {
  port: process.env.PORT || 3000,
  env: process.env.NODE_ENV || 'development',
  db: {
    url: process.env.DATABASE_URL
  },
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD || null
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d'
  },
  gateways: {
    twilio: {
      accountSid: process.env.TWILIO_ACCOUNT_SID,
      authToken: process.env.TWILIO_AUTH_TOKEN
    },
    infobip: {
      baseUrl: process.env.INFOBIP_API_BASE_URL || 'api.infobip.com',
      apiKey: process.env.INFOBIP_API_KEY
    },
    defaultTps: parseInt(process.env.DEFAULT_TPS || '10', 10)
  },
  webhook: {
    secret: process.env.WEBHOOK_SIGNING_SECRET || 'super_secret_webhook_signing_key_12345'
  }
};

