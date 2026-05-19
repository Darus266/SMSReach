const { PrismaClient } = require('@prisma/client');
const logger = require('../utils/logger');

const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'info', 'warn', 'error'] : ['error'],
});

prisma.$connect()
  .then(() => logger.info('Prisma connected to PostgreSQL successfully.'))
  .catch((err) => logger.error('Failed to connect Prisma to PostgreSQL', err));

module.exports = prisma;
