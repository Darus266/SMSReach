const express = require('express');
const router = express.Router();
const campaignController = require('../controllers/campaign.controller');
const { verifyToken } = require('../middlewares/auth.middleware');
const { validate } = require('../middlewares/validate.middleware');
const { createCampaignSchema, sendCampaignSchema } = require('../utils/validation');

router.use(verifyToken);

router.post('/', validate(createCampaignSchema), campaignController.createCampaign);
router.post('/:id/send', validate(sendCampaignSchema), campaignController.sendCampaign);
router.get('/', campaignController.getCampaigns);
router.get('/:id/stats', campaignController.getCampaignStats);

module.exports = router;

