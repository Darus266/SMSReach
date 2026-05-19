const prisma = require('../config/prisma');
const logger = require('../utils/logger');

exports.requestSenderId = async (companyId, name) => {
  const existing = await prisma.senderId.findUnique({
    where: {
      companyId_name: { companyId, name }
    }
  });

  if (existing) {
    throw new Error(`Sender ID '${name}' already exists for this company.`);
  }

  const sender = await prisma.senderId.create({
    data: { companyId, name, status: 'PENDING' }
  });

  logger.info(`New Sender ID requested: '${name}' for company ${companyId}`);
  return sender;
};

exports.approveSenderId = async (senderId) => {
  const sender = await prisma.senderId.findUnique({
    where: { id: senderId }
  });

  if (!sender) {
    throw new Error('Sender ID not found.');
  }

  const updated = await prisma.senderId.update({
    where: { id: senderId },
    data: { status: 'APPROVED', updatedAt: new Date() }
  });

  logger.info(`Sender ID '${updated.name}' approved.`);
  return updated;
};

exports.getApprovedSenderIds = async (companyId) => {
  return prisma.senderId.findMany({
    where: { companyId, status: 'APPROVED' }
  });
};
