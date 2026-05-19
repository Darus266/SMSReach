const prisma = require('../config/prisma');
const logger = require('../utils/logger');

exports.checkBalance = async (companyId) => {
  const wallet = await prisma.wallet.findUnique({
    where: { companyId }
  });

  if (!wallet) {
    throw new Error('Wallet not found for this company.');
  }

  return wallet.balance.toNumber();
};

exports.deductCredits = async (companyId, amount, referenceId, description) => {
  const result = await prisma.$transaction(async (tx) => {
    const wallet = await tx.wallet.findUnique({
      where: { companyId }
    });

    if (!wallet || wallet.balance.toNumber() < amount) {
      throw new Error('Insufficient balance.');
    }

    const updatedWallet = await tx.wallet.update({
      where: { companyId },
      data: {
        balance: { decrement: amount }
      }
    });

    await tx.walletTransaction.create({
      data: {
        walletId: wallet.id,
        amount: -amount,
        type: 'DEBIT_SMS',
        referenceId: referenceId || null,
        description: description || 'SMS credit deduction'
      }
    });

    return updatedWallet.balance.toNumber();
  });

  return result;
};

exports.addCredits = async (companyId, amount, referenceId, description) => {
  const result = await prisma.$transaction(async (tx) => {
    const wallet = await tx.wallet.findUnique({
      where: { companyId }
    });

    if (!wallet) {
      throw new Error('Wallet not found.');
    }

    const updatedWallet = await tx.wallet.update({
      where: { companyId },
      data: {
        balance: { increment: amount }
      }
    });

    await tx.walletTransaction.create({
      data: {
        walletId: wallet.id,
        amount: amount,
        type: 'DEPOSIT',
        referenceId: referenceId || null,
        description: description || 'Credit top-up'
      }
    });

    logger.info(`Credits added for company ${companyId}: +${amount}`);
    return updatedWallet.balance.toNumber();
  });

  return result;
};
