const logger = require('../utils/logger');

module.exports = (err, req, res, next) => {
  logger.error(`${req.method} ${req.path} - Express Error Handler: ${err.message}`, err);

  const status = err.statusCode || 500;
  const response = {
    success: false,
    message: err.message || 'Internal Server Error',
    timestamp: new Date().toISOString()
  };

  // Do not leak stacktrace in production
  if (process.env.NODE_ENV === 'development') {
    response.stack = err.stack;
  }

  res.status(status).json(response);
};
