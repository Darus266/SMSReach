const express = require('express');
const router = express.Router();

const authRoutes = require('./auth.routes');
const smsRoutes = require('./sms.routes');
const campaignRoutes = require('./campaign.routes');
const senderIdRoutes = require('./senderId.routes');
const billingRoutes = require('./billing.routes');

// Public endpoints
router.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'SaaS SMS Platform API is fully healthy.',
    timestamp: new Date().toISOString()
  });
});

// Mounted features
router.use('/auth', authRoutes);
router.use('/sms', smsRoutes);
router.use('/campaigns', campaignRoutes);
router.use('/sender-ids', senderIdRoutes);
router.use('/billing', billingRoutes);

module.exports = router;
