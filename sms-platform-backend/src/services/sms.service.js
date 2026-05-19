const prisma = require('../config/prisma');
const logger = require('../utils/logger');
const queueService = require('./queue.service');
const rechargeService = require('./recharge.service');

// Calculate cost dynamically based on routing/prefix
const getSmsCost = (phoneNumber) => {
  if (phoneNumber.startsWith('+225')) return 0.0450; // Ivory Coast Local rate
  if (phoneNumber.startsWith('+33')) return 0.0250; // France rate
  return 0.0500; // Default international rate
};

/**
 * Validates balance, debits wallet, logs PENDING status and enqueues SMS for delivery
 */
exports.sendSingleSms = async (companyId, { to, message, senderId }) => {
  const cost = getSmsCost(to);

  logger.info(`Initiating SMS processing to ${to} for Company ${companyId}. Cost: ${cost} credits`);

  // Use transaction to ensure billing and logging are completely atomic (No race conditions)
  const result = await prisma.$transaction(async (tx) => {
    // 1. Fetch wallet & lock it (SaaS billing security)
    const wallet = await tx.wallet.findUnique({
      where: { companyId }
    });

    if (!wallet || wallet.balance.toNumber() < cost) {
      throw new Error('Insufficient balance in wallet to send SMS.');
    }

    // 2. Deduct credit amount
    await tx.wallet.update({
      where: { companyId },
      data: {
        balance: {
          decrement: cost
        }
      }
    });

    // 3. Create PENDING SMS Log
    const smsLog = await tx.smsLog.create({
      data: {
        companyId,
        senderIdName: senderId,
        recipient: to,
        message,
        status: 'PENDING',
        cost: cost
      }
    });

    // 4. Create Wallet Ledger Transaction record
    await tx.walletTransaction.create({
      data: {
        walletId: wallet.id,
        amount: -cost,
        type: 'DEBIT_SMS',
        referenceId: smsLog.id.toString(),
        description: `SMS debit for ${to} via Sender ID [${senderId}]`
      }
    });

    return smsLog;
  });

  // 5. Connect to SMS Gateway through Background Worker Queue
  // To avoid blocking HTTP API and handle retries/load-balancing, we push to BullMQ
  await queueService.addSmsJob({
    smsId: result.id.toString(),
    createdAt: result.createdAt.toISOString(),
    to,
    message,
    senderId,
    companyId,
    cost: cost
  });

  logger.info(`SMS ${result.id} successfully queued in BullMQ.`);

  // 6. Trigger auto-recharge check asynchronously
  rechargeService.checkAndTriggerAutoRecharge(companyId).catch(err => {
    logger.error('Failed to trigger auto-recharge check asynchronously', err);
  });
  
  return result;
};
