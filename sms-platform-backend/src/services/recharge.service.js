const prisma = require('../config/prisma');
const logger = require('../utils/logger');

class RechargeService {
  /**
   * Checks if a company's wallet balance has fallen below their auto-recharge threshold,
   * and automatically initiates a recurring Mobile Money charge simulation if configured.
   */
  async checkAndTriggerAutoRecharge(companyId) {
    try {
      const wallet = await prisma.wallet.findUnique({
        where: { companyId },
        include: { autoRechargeSetting: true }
      });

      if (!wallet || !wallet.autoRechargeSetting || !wallet.autoRechargeSetting.enabled) {
        return;
      }

      const settings = wallet.autoRechargeSetting;
      const balanceVal = wallet.balance.toNumber();
      const thresholdVal = settings.threshold.toNumber();
      const rechargeAmountVal = settings.rechargeAmount.toNumber();

      if (balanceVal < thresholdVal) {
        logger.info(`[AUTO-RECHARGE] Balance ${balanceVal} < Threshold ${thresholdVal} for Company ${companyId}. Triggering auto-recharge of ${rechargeAmountVal} credits via ${settings.provider}.`);

        // Initialize a payment transaction record
        const payment = await prisma.paymentTransaction.create({
          data: {
            walletId: wallet.id,
            amount: rechargeAmountVal * 655.957, // Convert to XOF
            creditsAdded: rechargeAmountVal,
            currency: 'XOF',
            provider: settings.provider,
            phoneNumber: settings.phoneNumber,
            status: 'PENDING',
            externalReference: `auto_ref_${Math.random().toString(36).substr(2, 9)}`
          }
        });

        // Atomically complete the payment transaction (recurring pre-authorized)
        await prisma.$transaction(async (tx) => {
          // 1. Mark transaction as SUCCESS
          await tx.paymentTransaction.update({
            where: { id: payment.id },
            data: { status: 'SUCCESS', updatedAt: new Date() }
          });

          // 2. Add credits to wallet balance
          await tx.wallet.update({
            where: { id: wallet.id },
            data: { balance: { increment: rechargeAmountVal }, updatedAt: new Date() }
          });

          // 3. Insert deposit transaction log
          await tx.walletTransaction.create({
            data: {
              walletId: wallet.id,
              amount: rechargeAmountVal,
              type: 'DEPOSIT',
              referenceId: payment.id,
              description: `Recharge automatique (Solde < ${thresholdVal} crédits) via ${settings.provider}`
            }
          });

          // 4. Create compliant Invoice
          const invoiceNum = `INV-AUTO-${new Date().getFullYear()}${(new Date().getMonth()+1).toString().padStart(2, '0')}${new Date().getDate().toString().padStart(2, '0')}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;
          await tx.invoice.create({
            data: {
              companyId,
              transactionId: payment.id,
              invoiceNumber: invoiceNum,
              billingName: `Recharge Automatique SendReach`,
              billingAddress: 'Déclenchement Automatique de Secours',
              subtotal: (rechargeAmountVal * 655.957) * 0.82, // HT
              tax: (rechargeAmountVal * 655.957) * 0.18,      // TVA 18%
              total: rechargeAmountVal * 655.957               // Total TTC
            }
          });

          logger.info(`[AUTO-RECHARGE] Successfully credited ${rechargeAmountVal} credits and generated invoice ${invoiceNum} for Company ${companyId}.`);
        });
      }
    } catch (err) {
      logger.error(`[AUTO-RECHARGE] Critical error checking auto-recharge for Company ${companyId}`, err);
    }
  }
}

module.exports = new RechargeService();
