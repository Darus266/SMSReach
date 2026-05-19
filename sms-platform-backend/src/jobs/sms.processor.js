const { Worker } = require('bullmq');
const config = require('../config');
const prisma = require('../config/prisma');
const logger = require('../utils/logger');
const gatewayService = require('../services/gateway.service');
const webhookService = require('../services/webhook.service');

// Shared Redis connection details
const connection = {
  host: config.redis.host,
  port: config.redis.port,
  password: config.redis.password || undefined
};

logger.info('Starting BullMQ SMS Queue Worker...');

const smsWorker = new Worker('smsQueue', async job => {
  const { smsId, createdAt, to, message, senderId, companyId, cost } = job.data;
  
  logger.info(`[WORKER] Processing SMS Job ${job.id} (smsId=${smsId}, recipient=${to})`);

  try {
    // 1. Dispatch SMS using gateway service with dynamic routing & failover
    const result = await gatewayService.sendWithFallback(to, message, senderId);

    logger.info(`[WORKER] SMS Job ${job.id} successfully sent. External ID: ${result.externalId}`);

    // 2. Update SMS log in DB to SENT
    await prisma.smsLog.update({
      where: {
        id_createdAt: {
          id: BigInt(smsId),
          createdAt: new Date(createdAt)
        }
      },
      data: {
        status: 'SENT',
        externalId: result.externalId,
        errorCode: null,
        updatedAt: new Date()
      }
    });

    // 3. Dispatch webhook status update to SaaS Client
    await webhookService.dispatchWebhook(companyId, 'sms.status_update', {
      id: smsId.toString(),
      recipient: to,
      senderId,
      status: 'SENT',
      errorCode: null,
      externalId: result.externalId,
      cost: parseFloat(cost)
    });

    return { status: 'SENT', externalId: result.externalId };

  } catch (err) {
    logger.error(`[WORKER] Error in smsWorker processing Job ${job.id}: ${err.message}`, err);

    // List of errors that cannot be solved by retrying (e.g. bad number, invalid credentials)
    const unrecoverableErrors = ['INVALID_RECIPIENT', 'SENDER_ID_REJECTED', 'GATEWAY_AUTH_FAILED'];
    const isUnrecoverable = unrecoverableErrors.includes(err.code);
    const isLastAttempt = job.attemptsMade + 1 >= job.opts.attempts;

    if (isUnrecoverable || isLastAttempt) {
      logger.warn(`[WORKER] SMS Job ${job.id} failed permanently. Reason: ${err.code || 'MAX_RETRIES_EXHAUSTED'}`);

      // A. Mark status as FAILED in database
      await prisma.smsLog.update({
        where: {
          id_createdAt: {
            id: BigInt(smsId),
            createdAt: new Date(createdAt)
          }
        },
        data: {
          status: 'FAILED',
          errorCode: err.code || 'GATEWAY_ERROR',
          updatedAt: new Date()
        }
      });

      // B. Automated Credit Refund (SaaS Financial Safeguard)
      const amountToRefund = parseFloat(cost);
      if (amountToRefund > 0) {
        logger.info(`[WORKER] Refunding ${amountToRefund} credits to Company ${companyId} for failed SMS ${smsId}`);
        
        try {
          await prisma.$transaction(async (tx) => {
            const wallet = await tx.wallet.findUnique({
              where: { companyId }
            });

            if (wallet) {
              // Refund wallet balance
              await tx.wallet.update({
                where: { companyId },
                data: {
                  balance: { increment: amountToRefund }
                }
              });

              // Write refund transaction ledger record
              await tx.walletTransaction.create({
                data: {
                  walletId: wallet.id,
                  amount: amountToRefund,
                  type: 'REFUND',
                  referenceId: smsId.toString(),
                  description: `Refund for failed SMS dispatch to ${to} (${err.code || 'GATEWAY_ERROR'})`
                }
              });
            }
          });
          logger.info(`[WORKER] Refund transactions successfully committed for SMS ${smsId}`);
        } catch (refundErr) {
          logger.error(`[WORKER] Critical: Wallet refund failed for SMS ${smsId}`, refundErr);
        }
      }

      // C. Dispatch failed webhook status update to Client
      await webhookService.dispatchWebhook(companyId, 'sms.status_update', {
        id: smsId.toString(),
        recipient: to,
        senderId,
        status: 'FAILED',
        errorCode: err.code || 'GATEWAY_ERROR',
        externalId: null,
        cost: 0 // zero cost because refunded
      });

      // If it is unrecoverable, we return a success code to BullMQ so it doesn't try to retry it
      if (isUnrecoverable) {
        return { status: 'FAILED_UNRECOVERABLE', errorCode: err.code };
      }
    }

    // Throw recoverable errors (timeouts, temporary 5xx) so BullMQ schedules retry with backoff
    throw err;
  }
}, { connection });

smsWorker.on('completed', job => {
  logger.info(`[WORKER] Job ${job.id} completed successfully.`);
});

smsWorker.on('failed', (job, err) => {
  logger.error(`[WORKER] Job ${job.id} has failed permanently: ${err.message}`);
});

module.exports = smsWorker;
