const { Worker } = require('bullmq');
const config = require('../config');
const prisma = require('../config/prisma');
const logger = require('../utils/logger');
const webhookService = require('../services/webhook.service');

// Shared Redis connection details
const connection = {
  host: config.redis.host,
  port: config.redis.port,
  password: config.redis.password || undefined
};

logger.info('Starting BullMQ DLR Queue Worker...');

const dlrWorker = new Worker('dlrQueue', async job => {
  const { externalId, operatorStatus, errorCode, provider } = job.data;
  
  logger.info(`[DLR WORKER] Processing DLR Job ${job.id} (externalId=${externalId}, provider=${provider}, status=${operatorStatus})`);

  // 1. Find SMS log by external operator ID
  const smsLog = await prisma.smsLog.findFirst({
    where: { externalId }
  });

  if (!smsLog) {
    logger.warn(`[DLR WORKER] SMS log not found for external ID: ${externalId}`);
    return { status: 'SKIPPED', reason: 'SMS log not found' };
  }

  // 2. Map operator status to our unified internal system statuses
  let internalStatus = smsLog.status;
  const normalizedStatus = (operatorStatus || '').toLowerCase();
  
  if (['delivered', 'delivered_to_handset'].includes(normalizedStatus)) {
    internalStatus = 'DELIVERED';
  } else if (['failed', 'undelivered', 'undeliverable', 'rejected'].includes(normalizedStatus)) {
    internalStatus = 'FAILED';
  } else if (['expired'].includes(normalizedStatus)) {
    internalStatus = 'EXPIRED';
  } else if (['sent', 'accepted'].includes(normalizedStatus)) {
    internalStatus = 'SENT';
  }

  logger.info(`[DLR WORKER] Status mapping for SMS ${smsLog.id}: ${smsLog.status} -> ${internalStatus}`);

  // 3. Financial Safety (Refund credits on carrier-level failures)
  // If transitioning to FAILED from a non-failed state, refund the debited credits
  if (internalStatus === 'FAILED' && smsLog.status !== 'FAILED') {
    const amountToRefund = parseFloat(smsLog.cost);
    if (amountToRefund > 0) {
      logger.info(`[DLR WORKER] Refunding ${amountToRefund} credits for carrier failure on SMS ${smsLog.id}`);
      try {
        await prisma.$transaction(async (tx) => {
          const wallet = await tx.wallet.findUnique({
            where: { companyId: smsLog.companyId }
          });

          if (wallet) {
            await tx.wallet.update({
              where: { companyId: smsLog.companyId },
              data: { balance: { increment: amountToRefund } }
            });

            await tx.walletTransaction.create({
              data: {
                walletId: wallet.id,
                amount: amountToRefund,
                type: 'REFUND',
                referenceId: smsLog.id.toString(),
                description: `Refund for carrier failure DLR (Error: ${errorCode || 'UNDELIVERABLE'})`
              }
            });
          }
        });
        logger.info(`[DLR WORKER] Wallet refund committed for SMS ${smsLog.id}`);
      } catch (refundErr) {
        logger.error(`[DLR WORKER] Critical: Wallet refund transaction failed for SMS ${smsLog.id}`, refundErr);
        throw refundErr; // Retry job if DB transaction failed
      }
    }
  }

  // 4. Update database log
  await prisma.smsLog.update({
    where: {
      id_createdAt: {
        id: smsLog.id,
        createdAt: smsLog.createdAt
      }
    },
    data: {
      status: internalStatus,
      errorCode: errorCode || smsLog.errorCode,
      updatedAt: new Date()
    }
  });

  // 5. Propagate DLR status update to client company's webhook URL
  await webhookService.dispatchWebhook(smsLog.companyId, 'sms.status_update', {
    id: smsLog.id.toString(),
    recipient: smsLog.recipient,
    senderId: smsLog.senderIdName,
    status: internalStatus,
    errorCode: errorCode || smsLog.errorCode,
    externalId: smsLog.externalId,
    cost: internalStatus === 'FAILED' ? 0 : parseFloat(smsLog.cost)
  });

  return { status: 'PROCESSED', internalStatus };
}, { connection });

dlrWorker.on('completed', job => {
  logger.info(`[DLR WORKER] Job ${job.id} completed successfully.`);
});

dlrWorker.on('failed', (job, err) => {
  logger.error(`[DLR WORKER] Job ${job.id} has failed permanently: ${err.message}`);
});

module.exports = dlrWorker;
