const smsService = require('../services/sms.service');
const prisma = require('../config/prisma');
const webhookService = require('../services/webhook.service');
const queueService = require('../services/queue.service');
const logger = require('../utils/logger');



exports.sendSms = async (req, res, next) => {
  const { to, message, senderId } = req.body;
  const companyId = req.user.companyId;

  try {
    // 1. Verify if the senderId is approved for this company
    const approvedSender = await prisma.senderId.findFirst({
      where: {
        companyId,
        name: senderId,
        status: 'APPROVED'
      }
    });

    if (!approvedSender) {
      return res.status(400).json({
        success: false,
        message: `The Sender ID '${senderId}' is not approved for your company. Please request approval first.`
      });
    }

    // 2. Process sending
    const smsLog = await smsService.sendSingleSms(companyId, { to, message, senderId });

    res.status(202).json({
      success: true,
      message: 'SMS successfully queued for transmission.',
      data: {
        id: smsLog.id.toString(),
        recipient: smsLog.recipient,
        cost: smsLog.cost,
        status: smsLog.status
      }
    });

  } catch (err) {
    if (err.message.includes('Insufficient balance')) {
      return res.status(402).json({
        success: false,
        message: err.message
      });
    }
    next(err);
  }
};

exports.getHistory = async (req, res, next) => {
  const companyId = req.user.companyId;
  const { limit = 20, page = 1, status } = req.query;

  try {
    const take = parseInt(limit);
    const skip = (parseInt(page) - 1) * take;

    const where = { companyId };
    if (status) {
      where.status = status.toUpperCase();
    }

    const [logs, total] = await prisma.$transaction([
      prisma.smsLog.findMany({
        where,
        take,
        skip,
        orderBy: { createdAt: 'desc' }
      }),
      prisma.smsLog.count({ where })
    ]);

    // Handle BigInt conversion to String for JSON rendering
    const formattedLogs = logs.map(log => ({
      ...log,
      id: log.id.toString()
    }));

    res.status(200).json({
      success: true,
      data: formattedLogs,
      meta: {
        total,
        page: parseInt(page),
        limit: take,
        pages: Math.ceil(total / take)
      }
    });

  } catch (err) {
    next(err);
  }
};

exports.receiveWebhook = async (req, res, next) => {
  try {
    let externalId = null;
    let operatorStatus = null;
    let errorCode = null;
    let provider = null;

    logger.info(`[DLR WEBHOOK] Received webhook request: ${JSON.stringify(req.body)}`);

    // 1. Identify and parse Webhook payloads (Twilio vs Infobip)
    if (req.body.MessageSid) {
      // Twilio Delivery Receipt format
      provider = 'twilio';
      externalId = req.body.MessageSid;
      operatorStatus = req.body.MessageStatus; // e.g. sent, delivered, failed, undelivered
      errorCode = req.body.ErrorCode || null;
    } else if (req.body.results && Array.isArray(req.body.results)) {
      // Infobip Delivery Receipt format
      provider = 'infobip';
      const result = req.body.results[0];
      externalId = result?.messageId;
      operatorStatus = result?.status?.groupName; // e.g. DELIVERED, REJECTED, UNDELIVERABLE, EXPIRED
      errorCode = result?.error?.name !== 'NO_ERROR' ? result?.error?.name : null;
    }

    if (!externalId) {
      logger.warn('[DLR WEBHOOK] Webhook skipped: unable to extract external message ID');
      return res.status(400).json({ success: false, message: 'Invalid payload: missing external message identifier.' });
    }

    // 2. Dispatch DLR processing to background queue for maximum speed and reliability
    await queueService.addDlrJob({
      externalId,
      operatorStatus,
      errorCode,
      provider
    });

    // 3. Respond immediately to Operator to release HTTP connection
    res.status(200).json({ success: true, message: 'Delivery receipt received and queued successfully.' });

  } catch (err) {
    next(err);
  }
};


