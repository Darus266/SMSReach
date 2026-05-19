const express = require('express');
const router = express.Router();
const senderIdController = require('../controllers/senderId.controller');
const { verifyToken, requireRole } = require('../middlewares/auth.middleware');
const { validate } = require('../middlewares/validate.middleware');
const { requestSenderIdSchema, approveSenderIdSchema } = require('../utils/validation');

router.use(verifyToken);

// Customer Routes
router.post('/', validate(requestSenderIdSchema), senderIdController.requestSenderId);
router.get('/', senderIdController.getSenderIds);

// Admin-Only Routes
router.post('/approve', requireRole(['admin']), validate(approveSenderIdSchema), senderIdController.approveSenderId);

module.exports = router;
