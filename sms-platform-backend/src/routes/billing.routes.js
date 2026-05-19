const express = require('express');
const router = express.Router();
const billingController = require('../controllers/billing.controller');
const { verifyToken } = require('../middlewares/auth.middleware');
const { validate } = require('../middlewares/validate.middleware');
const { depositSchema } = require('../utils/validation');

// 1. PUBLIC WEBHOOK (Called by operators like Wave/Orange, verified cryptographically inside controller)
router.post('/webhook', billingController.handleWebhook);

// 2. PROTECTED USER ROUTES
router.use(verifyToken);

router.get('/balance', billingController.getBalance);
router.post('/deposit', validate(depositSchema), billingController.deposit);
router.get('/transactions', billingController.getTransactions);

// Mobile Money Payments
router.post('/payments/initialize', billingController.initializePayment);
router.get('/payments/invoices', billingController.getInvoices);
router.get('/payments/invoices/:id/download', billingController.downloadInvoice);

// Automatic Recharge Configuration
router.get('/payments/auto-recharge', billingController.getAutoRechargeSetting);
router.post('/payments/auto-recharge', billingController.updateAutoRechargeSetting);

module.exports = router;
