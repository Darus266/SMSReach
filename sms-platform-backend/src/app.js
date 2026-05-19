require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const routes = require('./routes');
const errorHandler = require('./middlewares/error.middleware');
const logger = require('./utils/logger');

const app = express();

// Trust reverse proxy (Render, Cloudflare, etc.) for secure rate limiting
app.set('trust proxy', 1);

// Security Middlewares
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate Limiting to prevent API abuse
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again after 15 minutes.'
  }
});
app.use(limiter);

// Central API Routes Loader
app.use('/api/v1', routes);

// Centralized Error Handling Middleware (must be after all routes)
app.use(errorHandler);

// Start background workers (BullMQ queue consumers)
require('./jobs/sms.processor');
require('./jobs/dlr.processor');
require('./jobs/campaign.processor');

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`SaaS SMS Platform Backend started on http://localhost:${PORT}`);
});


module.exports = app;
