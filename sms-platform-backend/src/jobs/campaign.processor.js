const { Worker } = require('bullmq');
const config = require('../config');
const prisma = require('../config/prisma');
const logger = require('../utils/logger');
const queueService = require('../services/queue.service');
const rechargeService = require('../services/recharge.service');

// Shared Redis connection details
const connection = {
  host: config.redis.host,
  port: config.redis.port,
  password: config.redis.password || undefined
};

// Calculate cost dynamically based on routing/prefix
const getSmsCost = (phoneNumber) => {
  if (phoneNumber.startsWith('+225')) return 0.0450; // Ivory Coast Local rate
  if (phoneNumber.startsWith('+33')) return 0.0250; // France rate
  return 0.0500; // Default international rate
};

logger.info('Starting BullMQ Campaign Queue Worker...');

const campaignWorker = new Worker('campaignQueue', async job => {
  const { campaignId, companyId, recipients, messageBody, senderIdName } = job.data;
  
  logger.info(`[CAMPAIGN WORKER] Processing Campaign ${campaignId} with ${recipients.length} recipients`);

  // 1. Calculate the total cost of the campaign dynamically
  let totalCost = 0;
  const smsLogsData = recipients.map(recipient => {
    const cost = getSmsCost(recipient);
    totalCost += cost;
    return {
      companyId,
      campaignId,
      senderIdName,
      recipient,
      message: messageBody,
      status: 'PENDING',
      cost: cost
    };
  });

  logger.info(`[CAMPAIGN WORKER] Calculated total cost for Campaign ${campaignId}: ${totalCost.toFixed(4)} credits`);

  try {
    // 2. Perform credit check and debit in an atomic transaction
    const dbResult = await prisma.$transaction(async (tx) => {
      // A. Verify balance
      const wallet = await tx.wallet.findUnique({
        where: { companyId }
      });

      if (!wallet || wallet.balance.toNumber() < totalCost) {
        throw new Error(`Insufficient wallet balance (${wallet?.balance?.toNumber() || 0}) for Campaign total cost (${totalCost})`);
      }

      // B. Deduct campaign cost from wallet
      await tx.wallet.update({
        where: { companyId },
        data: {
          balance: { decrement: totalCost }
        }
      });

      // C. Update Campaign status to SENDING
      await tx.campaign.update({
        where: { id: campaignId },
        data: { status: 'SENDING', updatedAt: new Date() }
      });

      // D. Insert all PENDING SMS logs in bulk for maximum database performance
      await tx.smsLog.createMany({
        data: smsLogsData
      });

      // E. Create Wallet Transaction Ledger
      await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          amount: -totalCost,
          type: 'DEBIT_SMS',
          referenceId: campaignId,
          description: `Bulk campaign debit for ${recipients.length} recipients`
        }
      });

      // F. Fetch back all logs created for this campaign to retrieve their database IDs
      const createdLogs = await tx.smsLog.findMany({
        where: { campaignId, companyId }
      });

      return createdLogs;
    });

    logger.info(`[CAMPAIGN WORKER] Successfully debited and bulk-inserted logs for ${dbResult.length} SMS`);

    // Trigger auto-recharge checks asynchronously after campaign debit
    rechargeService.checkAndTriggerAutoRecharge(companyId).catch(err => {
      logger.error('[CAMPAIGN WORKER] Failed to execute auto-recharge check asynchronously', err);
    });

    // 3. Queue individual SMS into the smsQueue with lissage/throttling (TPS limit)
    const tps = config.gateways.defaultTps;
    const intervalMs = Math.floor(1000 / tps); // e.g. 100ms for 10 TPS
    
    logger.info(`[CAMPAIGN WORKER] Queueing individual SMS tasks at rate limit: ${tps} TPS (${intervalMs}ms spacing)`);

    const queuePromises = dbResult.map((smsLog, index) => {
      // Calculate delay offset to throttle the dispatch rate
      const delay = index * intervalMs;
      
      const jobData = {
        smsId: smsLog.id.toString(),
        createdAt: smsLog.createdAt.toISOString(),
        to: smsLog.recipient,
        message: smsLog.message,
        senderId: smsLog.senderIdName,
        companyId: smsLog.companyId,
        cost: parseFloat(smsLog.cost)
      };

      return queueService.addSmsJob(jobData, { delay });
    });

    await Promise.all(queuePromises);
    logger.info(`[CAMPAIGN WORKER] Queued all ${recipients.length} messages in smsQueue.`);

    // 4. Update campaign status to COMPLETED
    await prisma.campaign.update({
      where: { id: campaignId },
      data: { status: 'COMPLETED', updatedAt: new Date() }
    });

    return { success: true, count: recipients.length };

  } catch (err) {
    logger.error(`[CAMPAIGN WORKER] Campaign ${campaignId} execution failed: ${err.message}`, err);

    // Fail campaign in database
    await prisma.campaign.update({
      where: { id: campaignId },
      data: { status: 'FAILED', updatedAt: new Date() }
    }).catch(e => logger.error('Failed to set campaign status to FAILED in catch block', e));

    // Create system audit log
    await prisma.systemLog.create({
      data: {
        level: 'ERROR',
        context: 'CAMPAIGN',
        message: `Campaign execution failed: ${err.message}`,
        metadata: { campaignId, companyId, totalRecipients: recipients.length }
      }
    }).catch(e => logger.error('Failed to log error inside SystemLog table', e));

    throw err;
  }
}, { connection });

campaignWorker.on('completed', job => {
  logger.info(`[CAMPAIGN WORKER] Campaign Job ${job.id} completed successfully.`);
});

campaignWorker.on('failed', (job, err) => {
  logger.error(`[CAMPAIGN WORKER] Campaign Job ${job.id} failed: ${err.message}`);
});

module.exports = campaignWorker;
