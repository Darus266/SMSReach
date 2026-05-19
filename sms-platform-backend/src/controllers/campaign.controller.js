const prisma = require('../config/prisma');
const queueService = require('../services/queue.service');


exports.createCampaign = async (req, res, next) => {
  const { name, senderId, messageBody, scheduledAt } = req.body;
  const companyId = req.user.companyId;

  try {
    // 1. Verify Sender ID belongs to this company and is approved
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
        message: `The Sender ID '${senderId}' is not approved for your company.`
      });
    }

    // 2. Create campaign
    const campaign = await prisma.campaign.create({
      data: {
        companyId,
        senderId: approvedSender.id,
        name,
        messageBody,
        status: scheduledAt ? 'SCHEDULED' : 'DRAFT',
        scheduledAt: scheduledAt ? new Date(scheduledAt) : null
      }
    });

    res.status(201).json({
      success: true,
      message: 'Campaign created successfully.',
      data: campaign
    });

  } catch (err) {
    next(err);
  }
};

exports.getCampaigns = async (req, res, next) => {
  const companyId = req.user.companyId;

  try {
    const campaigns = await prisma.campaign.findMany({
      where: { companyId },
      include: {
        sender: true
      },
      orderBy: { createdAt: 'desc' }
    });

    res.status(200).json({
      success: true,
      data: campaigns
    });

  } catch (err) {
    next(err);
  }
};

exports.getCampaignStats = async (req, res, next) => {
  const { id } = req.params;
  const companyId = req.user.companyId;

  try {
    // Verify campaign belongs to the user's company (SaaS Tenant Security)
    const campaign = await prisma.campaign.findFirst({
      where: { id, companyId }
    });

    if (!campaign) {
      return res.status(404).json({
        success: false,
        message: 'Campaign not found.'
      });
    }

    // Aggregate SMS stats in PostgreSQL
    const stats = await prisma.smsLog.groupBy({
      by: ['status'],
      where: { campaignId: id },
      _count: {
        status: true
      }
    });

    // Formatting statistics nicely
    const summary = {
      total: 0,
      sent: 0,
      delivered: 0,
      failed: 0,
      pending: 0
    };

    stats.forEach(stat => {
      const count = stat._count.status;
      summary.total += count;
      if (stat.status === 'SENT') summary.sent = count;
      if (stat.status === 'DELIVERED') summary.delivered = count;
      if (stat.status === 'FAILED') summary.failed = count;
      if (stat.status === 'PENDING') summary.pending = count;
    });

    res.status(200).json({
      success: true,
      data: {
        campaignId: id,
        name: campaign.name,
        stats: summary
      }
    });

  } catch (err) {
    next(err);
  }
};

exports.sendCampaign = async (req, res, next) => {
  const { id } = req.params;
  const { recipients } = req.body;
  const companyId = req.user.companyId;

  try {
    // 1. Verify campaign exists and belongs to this company (SaaS Tenant Security)
    const campaign = await prisma.campaign.findFirst({
      where: { id, companyId },
      include: { sender: true }
    });

    if (!campaign) {
      return res.status(404).json({
        success: false,
        message: 'Campaign not found.'
      });
    }

    // 2. Validate current status to prevent double-submitting campaigns
    if (campaign.status === 'SENDING' || campaign.status === 'COMPLETED') {
      return res.status(400).json({
        success: false,
        message: `Campaign is already in '${campaign.status}' state and cannot be sent again.`
      });
    }

    if (!campaign.sender) {
      return res.status(400).json({
        success: false,
        message: 'The campaign does not have an approved Sender ID configured.'
      });
    }

    // 3. Update status to SCHEDULED (or SENDING) to lock it immediately
    const updatedCampaign = await prisma.campaign.update({
      where: { id },
      data: { status: 'SCHEDULED', updatedAt: new Date() }
    });

    // 4. Dispatch campaign processing task to BullMQ
    await queueService.addCampaignJob({
      campaignId: campaign.id,
      companyId,
      recipients,
      messageBody: campaign.messageBody,
      senderIdName: campaign.sender.name
    });

    res.status(202).json({
      success: true,
      message: 'Campaign queued successfully for background execution.',
      data: {
        campaignId: campaign.id,
        status: 'QUEUED',
        recipientCount: recipients.length
      }
    });

  } catch (err) {
    next(err);
  }
};

