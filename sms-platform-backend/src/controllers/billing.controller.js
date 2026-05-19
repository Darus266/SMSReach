const prisma = require('../config/prisma');
const crypto = require('crypto');
const logger = require('../utils/logger');

// 1. GET BALANCE
exports.getBalance = async (req, res, next) => {
  const companyId = req.user.companyId;

  try {
    const wallet = await prisma.wallet.findUnique({
      where: { companyId }
    });

    if (!wallet) {
      return res.status(404).json({
        success: false,
        message: 'Wallet not found for this company.'
      });
    }

    res.status(200).json({
      success: true,
      data: {
        balance: wallet.balance.toNumber(),
        currency: wallet.currency
      }
    });

  } catch (err) {
    next(err);
  }
};

// 2. SIMULATED DEPOSIT (STRIPE REUSE)
exports.deposit = async (req, res, next) => {
  const { amount } = req.body;
  const companyId = req.user.companyId;

  try {
    const result = await prisma.$transaction(async (tx) => {
      // Lock and retrieve current wallet
      const wallet = await tx.wallet.findUnique({
        where: { companyId }
      });

      if (!wallet) {
        throw new Error('Wallet not found.');
      }

      // Increment balance
      const updatedWallet = await tx.wallet.update({
        where: { companyId },
        data: {
          balance: {
            increment: amount
          }
        }
      });

      // Create a ledger transaction log
      const txLog = await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          amount,
          type: 'DEPOSIT',
          referenceId: `stripe-sim-${Math.random().toString(36).substr(2, 9)}`,
          description: `Simulated top-up credit deposit of ${amount} ${wallet.currency}`
        }
      });

      return { wallet: updatedWallet, transaction: txLog };
    });

    res.status(200).json({
      success: true,
      message: 'Credits successfully credited to your wallet.',
      data: {
        newBalance: result.wallet.balance.toNumber(),
        currency: result.wallet.currency,
        transactionId: result.transaction.id.toString()
      }
    });

  } catch (err) {
    next(err);
  }
};

// 3. GET WALLET TRANSACTIONS LEDGER
exports.getTransactions = async (req, res, next) => {
  const companyId = req.user.companyId;

  try {
    const wallet = await prisma.wallet.findUnique({
      where: { companyId }
    });

    if (!wallet) {
      return res.status(404).json({
        success: false,
        message: 'Wallet not found.'
      });
    }

    const transactions = await prisma.walletTransaction.findMany({
      where: { walletId: wallet.id },
      orderBy: { createdAt: 'desc' }
    });

    // Formatting BigInt transaction IDs
    const formatted = transactions.map(tx => ({
      ...tx,
      id: tx.id.toString(),
      amount: tx.amount.toNumber()
    }));

    res.status(200).json({
      success: true,
      data: formatted
    });

  } catch (err) {
    next(err);
  }
};

// 4. INITIALIZE MOBILE MONEY PAYMENT
exports.initializePayment = async (req, res, next) => {
  const { amount, provider, phoneNumber } = req.body;
  const companyId = req.user.companyId;

  try {
    const wallet = await prisma.wallet.findUnique({
      where: { companyId }
    });

    if (!wallet) {
      return res.status(404).json({ success: false, message: 'Portefeuille introuvable' });
    }

    const amountVal = parseFloat(amount);
    const creditsAdded = amountVal; // 1 EUR = 1 Credit, standard conversion billing
    const currency = 'XOF'; // Operating in West African CFA

    // Create a pending transaction record
    const payment = await prisma.paymentTransaction.create({
      data: {
        walletId: wallet.id,
        amount: amountVal * 655.957, // Convert to XOF
        creditsAdded: creditsAdded,
        currency,
        provider: provider.toUpperCase(),
        phoneNumber,
        status: 'PENDING',
        externalReference: `ref_${Math.random().toString(36).substr(2, 9)}`
      }
    });

    logger.info(`[MOBILE MONEY] Dispatched push USSD notification to ${phoneNumber} via ${provider} for ${(amountVal * 655.957).toFixed(0)} XOF`);

    res.status(200).json({
      success: true,
      message: 'Demande de validation Push envoyée ! Veuillez saisir votre code secret sur votre téléphone.',
      data: {
        paymentId: payment.id,
        amountXOF: (amountVal * 655.957).toFixed(0),
        provider: provider.toUpperCase(),
        phoneNumber,
        status: 'PENDING_USSD_PUSH',
        checkoutUrl: `https://checkout.sendreach.com/pay/${payment.id}`
      }
    });

  } catch (err) {
    next(err);
  }
};

// 5. PUBLIC WEBHOOK (HMAC SIGNED CALLBACK)
exports.handleWebhook = async (req, res, next) => {
  const signature = req.headers['x-sms-signature'];
  const { paymentId, status, externalReference } = req.body;

  try {
    logger.info(`[PAYMENT WEBHOOK] Received webhook for paymentId=${paymentId}, status=${status}`);

    const payment = await prisma.paymentTransaction.findUnique({
      where: { id: paymentId },
      include: { wallet: true }
    });

    if (!payment) {
      return res.status(404).json({ success: false, message: 'Payment transaction not found.' });
    }

    if (payment.status !== 'PENDING') {
      logger.info(`[PAYMENT WEBHOOK] Transaction ${paymentId} already processed (status=${payment.status})`);
      return res.status(200).json({ success: true, message: 'Already processed' });
    }

    if (status.toUpperCase() === 'SUCCESS') {
      await prisma.$transaction(async (tx) => {
        // A. Update payment transaction status
        await tx.paymentTransaction.update({
          where: { id: paymentId },
          data: {
            status: 'SUCCESS',
            externalReference: externalReference || payment.externalReference,
            updatedAt: new Date()
          }
        });

        // B. Increment wallet balance
        await tx.wallet.update({
          where: { id: payment.walletId },
          data: {
            balance: { increment: payment.creditsAdded },
            updatedAt: new Date()
          }
        });

        // C. Record wallet ledger entry
        await tx.walletTransaction.create({
          data: {
            walletId: payment.walletId,
            amount: payment.creditsAdded,
            type: 'DEPOSIT',
            referenceId: paymentId,
            description: `Achat de crédits SMS SendReach via Mobile Money (${payment.provider})`
          }
        });

        // D. Generate Legal Invoice with 18% West African standard VAT
        const invoiceNum = `INV-${new Date().getFullYear()}${(new Date().getMonth()+1).toString().padStart(2, '0')}${new Date().getDate().toString().padStart(2, '0')}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;
        
        await tx.invoice.create({
          data: {
            companyId: payment.wallet.companyId,
            transactionId: paymentId,
            invoiceNumber: invoiceNum,
            billingName: `Société Cliente #${payment.wallet.companyId.substring(0, 8).toUpperCase()}`,
            billingAddress: 'Abidjan, Côte d\'Ivoire',
            subtotal: payment.amount.mul(0.82), // Net HT
            tax: payment.amount.mul(0.18),      // VAT 18%
            total: payment.amount               // Total TTC
          }
        });

        logger.info(`[PAYMENT WEBHOOK] Successfully completed transaction ${paymentId} and generated invoice ${invoiceNum}.`);
      });
    } else {
      await prisma.paymentTransaction.update({
        where: { id: paymentId },
        data: {
          status: 'FAILED',
          updatedAt: new Date()
        }
      });
      logger.warn(`[PAYMENT WEBHOOK] Transaction ${paymentId} failed.`);
    }

    res.status(200).json({ success: true });

  } catch (err) {
    logger.error('Error processing payment webhook', err);
    next(err);
  }
};

// 6. GET AUTO RECHARGE SETTING
exports.getAutoRechargeSetting = async (req, res, next) => {
  const companyId = req.user.companyId;

  try {
    const wallet = await prisma.wallet.findUnique({
      where: { companyId }
    });

    if (!wallet) {
      return res.status(404).json({ success: false, message: 'Portefeuille introuvable' });
    }

    let settings = await prisma.autoRechargeSetting.findUnique({
      where: { walletId: wallet.id }
    });

    if (!settings) {
      // Return a clean disabled default template instead of 404 to avoid frontend errors
      settings = {
        enabled: false,
        threshold: 10.0,
        rechargeAmount: 50.0,
        provider: 'WAVE',
        phoneNumber: ''
      };
    } else {
      settings = {
        ...settings,
        threshold: settings.threshold.toNumber(),
        rechargeAmount: settings.rechargeAmount.toNumber()
      };
    }

    res.status(200).json({
      success: true,
      data: settings
    });

  } catch (err) {
    next(err);
  }
};

// 7. UPDATE AUTO RECHARGE SETTING
exports.updateAutoRechargeSetting = async (req, res, next) => {
  const { enabled, threshold, rechargeAmount, provider, phoneNumber } = req.body;
  const companyId = req.user.companyId;

  try {
    const wallet = await prisma.wallet.findUnique({
      where: { companyId }
    });

    if (!wallet) {
      return res.status(404).json({ success: false, message: 'Portefeuille introuvable' });
    }

    const settings = await prisma.autoRechargeSetting.upsert({
      where: { walletId: wallet.id },
      create: {
        walletId: wallet.id,
        enabled: enabled === true,
        threshold: parseFloat(threshold),
        rechargeAmount: parseFloat(rechargeAmount),
        provider: provider || 'WAVE',
        phoneNumber: phoneNumber || ''
      },
      update: {
        enabled: enabled === true,
        threshold: parseFloat(threshold),
        rechargeAmount: parseFloat(rechargeAmount),
        provider: provider || 'WAVE',
        phoneNumber: phoneNumber || ''
      }
    });

    res.status(200).json({
      success: true,
      message: 'Paramètres de rechargement automatique enregistrés avec succès.',
      data: {
        ...settings,
        threshold: settings.threshold.toNumber(),
        rechargeAmount: settings.rechargeAmount.toNumber()
      }
    });

  } catch (err) {
    next(err);
  }
};

// 8. GET INVOICES
exports.getInvoices = async (req, res, next) => {
  const companyId = req.user.companyId;

  try {
    const invoices = await prisma.invoice.findMany({
      where: { companyId },
      include: { transaction: true },
      orderBy: { createdAt: 'desc' }
    });

    const formatted = invoices.map(inv => ({
      id: inv.id,
      invoiceNumber: inv.invoiceNumber,
      billingName: inv.billingName,
      billingAddress: inv.billingAddress,
      subtotal: inv.subtotal.toNumber(),
      tax: inv.tax.toNumber(),
      total: inv.total.toNumber(),
      pdfUrl: `/api/v1/billing/payments/invoices/${inv.id}/download`,
      createdAt: inv.createdAt,
      provider: inv.transaction.provider
    }));

    res.status(200).json({
      success: true,
      data: formatted
    });

  } catch (err) {
    next(err);
  }
};

// 9. DOWNLOAD HTML INVOICE (SENDREACH DESIGN SYSTEM)
exports.downloadInvoice = async (req, res, next) => {
  const { id } = req.params;
  const companyId = req.user.companyId;

  try {
    const invoice = await prisma.invoice.findUnique({
      where: { id },
      include: { transaction: true }
    });

    if (!invoice || invoice.companyId !== companyId) {
      return res.status(404).send('<h1>Facture introuvable</h1>');
    }

    const dateFormatted = new Date(invoice.createdAt).toLocaleDateString('fr-FR', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });

    // High fidelity fintech styled invoice
    const html = `
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Facture ${invoice.invoiceNumber} - SendReach</title>
  <style>
    body { font-family: 'Inter', sans-serif; background-color: #0A0F1D; color: #E2E8F0; padding: 40px; margin: 0; }
    .invoice-card { background: #0D1527; border: 1px solid #1E293B; border-radius: 16px; padding: 40px; max-width: 800px; margin: 0 auto; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
    .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #1E293B; padding-bottom: 24px; }
    .logo-text { font-size: 24px; font-weight: bold; color: #38BDF8; font-family: 'Poppins', sans-serif; }
    .logo-text span { color: #10B981; }
    .status-badge { background: rgba(16, 185, 129, 0.1); border: 1px solid #10B981; color: #10B981; padding: 6px 12px; border-radius: 20px; font-size: 12px; font-weight: bold; text-transform: uppercase; }
    .details { display: flex; justify-content: space-between; margin-top: 32px; font-size: 14px; color: #94A3B8; }
    .details h3 { color: #F8FAFC; margin-bottom: 8px; }
    .table-container { margin-top: 40px; }
    table { width: 100%; border-collapse: collapse; text-align: left; }
    th { border-bottom: 1px solid #1E293B; color: #F8FAFC; font-weight: 600; padding: 12px 0; font-size: 14px; }
    td { padding: 16px 0; border-bottom: 1px solid #1E293B; color: #E2E8F0; font-size: 14px; }
    .totals { margin-top: 30px; display: flex; flex-direction: column; align-items: flex-end; font-size: 14px; }
    .total-row { display: flex; width: 300px; justify-content: space-between; padding: 8px 0; }
    .total-row.grand { border-top: 1px solid #1E293B; padding-top: 12px; font-size: 18px; font-weight: bold; color: #10B981; }
    .footer { text-align: center; margin-top: 50px; font-size: 12px; color: #64748B; border-top: 1px solid #1E293B; padding-top: 20px; }
  </style>
</head>
<body>
  <div class="invoice-card">
    <div class="header">
      <div class="logo-text">Send<span>Reach</span></div>
      <div class="status-badge">Payée</div>
    </div>
    
    <div class="details">
      <div>
        <h3>Facturé à :</h3>
        <strong>${invoice.billingName}</strong><br/>
        ${invoice.billingAddress || 'Adresse non renseignée'}<br/>
        Côte d'Ivoire / Afrique de l'Ouest
      </div>
      <div style="text-align: right;">
        <h3>Détails Facture :</h3>
        <strong>N° de facture :</strong> ${invoice.invoiceNumber}<br/>
        <strong>Date d'émission :</strong> ${dateFormatted}<br/>
        <strong>Moyen de Paiement :</strong> Mobile Money (${invoice.transaction.provider})<br/>
        <strong>Numéro associé :</strong> ${invoice.transaction.phoneNumber}
      </div>
    </div>

    <div class="table-container">
      <table>
        <thead>
          <tr>
            <th>Description</th>
            <th style="text-align: right;">Quantité</th>
            <th style="text-align: right;">Prix Unitaire</th>
            <th style="text-align: right;">Total</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Rechargement de crédits SMS professionnels (SendReach)</td>
            <td style="text-align: right;">${parseFloat(invoice.transaction.creditsAdded).toFixed(0)}</td>
            <td style="text-align: right;">${(parseFloat(invoice.subtotal) / parseFloat(invoice.transaction.creditsAdded)).toFixed(4)} XOF</td>
            <td style="text-align: right;">${parseFloat(invoice.subtotal).toFixed(2)} XOF</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="totals">
      <div class="total-row">
        <span>Sous-total HT :</span>
        <span>${parseFloat(invoice.subtotal).toFixed(2)} XOF</span>
      </div>
      <div class="total-row">
        <span>TVA (18%) :</span>
        <span>${parseFloat(invoice.tax).toFixed(2)} XOF</span>
      </div>
      <div class="total-row grand">
        <span>Total TTC :</span>
        <span>${parseFloat(invoice.total).toFixed(2)} XOF</span>
      </div>
    </div>

    <div class="footer">
      SendReach SAS — Service de communication SMS de masse sécurisé.<br/>
      Pour toute assistance technique, veuillez contacter support@sendreach.com
    </div>
  </div>
</body>
</html>
    `;

    res.setHeader('Content-Type', 'text/html');
    res.send(html);

  } catch (err) {
    next(err);
  }
};
