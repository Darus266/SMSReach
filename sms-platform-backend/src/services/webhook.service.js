const crypto = require('crypto');
const prisma = require('../config/prisma');
const config = require('../config');
const logger = require('../utils/logger');

class WebhookService {
  /**
   * Generates an HMAC-SHA256 signature for the webhook payload
   */
  generateSignature(payload, secret) {
    return crypto
      .createHmac('sha256', secret)
      .update(JSON.stringify(payload))
      .digest('hex');
  }

  /**
   * Asynchronously dispatches a DLR webhook event to the client company
   */
  async dispatchWebhook(companyId, eventName, eventData) {
    try {
      // 1. Fetch client company to get webhookUrl
      const company = await prisma.company.findUnique({
        where: { id: companyId }
      });

      if (!company || !company.webhookUrl) {
        // No webhook URL configured, skip silently
        return;
      }

      logger.info(`Preparing to dispatch outbound webhook [${eventName}] for Company ${companyId} to ${company.webhookUrl}`);

      const payload = {
        event: eventName,
        timestamp: new Date().toISOString(),
        data: eventData
      };

      const signature = this.generateSignature(payload, config.webhook.secret);

      // 2. Perform HTTP POST dispatch with retries
      let retries = 3;
      let success = false;
      let delay = 1000; // start with 1 second delay

      while (retries > 0 && !success) {
        try {
          const controller = new AbortController();
          const timeoutId = setTimeout(() => controller.abort(), 5000); // 5s timeout

          const response = await fetch(company.webhookUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-SMS-Signature': signature,
              'User-Agent': 'SaaS-SMS-Gateway-Webhook/1.0'
            },
            body: JSON.stringify(payload),
            signal: controller.signal
          });

          clearTimeout(timeoutId);

          if (response.ok) {
            success = true;
            logger.info(`Outbound webhook for SMS ${eventData.id} delivered successfully to ${company.webhookUrl}`);
          } else {
            logger.warn(`Client webhook returned status ${response.status}. Retries left: ${retries - 1}`);
          }
        } catch (err) {
          logger.error(`Client webhook connection failed for SMS ${eventData.id}. Retries left: ${retries - 1}`, err);
        }

        if (!success) {
          retries--;
          if (retries > 0) {
            await new Promise(resolve => setTimeout(resolve, delay));
            delay *= 2; // exponential backoff
          }
        }
      }

      if (!success) {
        logger.error(`Failed to deliver webhook for SMS ${eventData.id} to ${company.webhookUrl} after all retries.`);
        
        // Optionally log webhook failure inside SystemLog table
        await prisma.systemLog.create({
          data: {
            level: 'WARN',
            context: 'WEBHOOK',
            message: `Outbound webhook delivery failed after 3 attempts. Target URL: ${company.webhookUrl}`,
            metadata: {
              companyId,
              eventId: eventData.id,
              recipient: eventData.recipient
            }
          }
        });
      }

    } catch (err) {
      logger.error('Error occurred in WebhookService.dispatchWebhook', err);
    }
  }
}

module.exports = new WebhookService();
