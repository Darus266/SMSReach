const express = require('express');
const router = express.Router();
const smsController = require('../controllers/sms.controller');
const { verifyToken } = require('../middlewares/auth.middleware');
const { validate } = require('../middlewares/validate.middleware');
const { smsLimiter } = require('../middlewares/rateLimit.middleware');
const { sendSmsSchema } = require('../utils/validation');

// Webhook endpoint is public (called by operators)
router.post('/webhook', smsController.receiveWebhook);

// Secured Client Routes
router.use(verifyToken);
router.post('/send', smsLimiter, validate(sendSmsSchema), smsController.sendSms);
router.get('/history', smsController.getHistory);

module.exports = router;
