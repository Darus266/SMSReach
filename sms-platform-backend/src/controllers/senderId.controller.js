const prisma = require('../config/prisma');

exports.requestSenderId = async (req, res, next) => {
  const { name } = req.body;
  const companyId = req.user.companyId;

  try {
    // Check if Sender ID already exists for this company
    const existing = await prisma.senderId.findUnique({
      where: {
        companyId_name: {
          companyId,
          name
        }
      }
    });

    if (existing) {
      return res.status(400).json({
        success: false,
        message: `The Sender ID '${name}' already exists or has been requested.`
      });
    }

    const sender = await prisma.senderId.create({
      data: {
        companyId,
        name,
        status: 'PENDING'
      }
    });

    res.status(201).json({
      success: true,
      message: 'Sender ID approval request submitted.',
      data: sender
    });

  } catch (err) {
    next(err);
  }
};

exports.getSenderIds = async (req, res, next) => {
  const companyId = req.user.companyId;

  try {
    const senders = await prisma.senderId.findMany({
      where: { companyId },
      orderBy: { createdAt: 'desc' }
    });

    res.status(200).json({
      success: true,
      data: senders
    });

  } catch (err) {
    next(err);
  }
};

exports.approveSenderId = async (req, res, next) => {
  const { senderId } = req.body;

  try {
    const sender = await prisma.senderId.findUnique({
      where: { id: senderId }
    });

    if (!sender) {
      return res.status(404).json({
        success: false,
        message: 'Sender ID not found.'
      });
    }

    const updated = await prisma.senderId.update({
      where: { id: senderId },
      data: {
        status: 'APPROVED',
        updatedAt: new Date()
      }
    });

    res.status(200).json({
      success: true,
      message: 'Sender ID successfully approved.',
      data: updated
    });

  } catch (err) {
    next(err);
  }
};
