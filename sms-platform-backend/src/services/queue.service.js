const { Queue } = require('bullmq');
const config = require('../config');
const logger = require('../utils/logger');

// Retrieve shared Redis connection details from configuration
const connection = {
  host: config.redis.host,
  port: config.redis.port,
  password: config.redis.password || undefined
};

logger.info(`Initializing BullMQ queues connecting to Redis on ${connection.host}:${connection.port}`);

// Initialize individual queues
const smsQueue = new Queue('smsQueue', { connection });
const campaignQueue = new Queue('campaignQueue', { connection });
const dlrQueue = new Queue('dlrQueue', { connection });

module.exports = {
  smsQueue,
  campaignQueue,
  dlrQueue,

  /**
   * Pushes a single SMS dispatch task to the background queue
   * Configures 3 retry attempts with exponential backoff.
   */
  async addSmsJob(data, options = {}) {
    return smsQueue.add('sendSms', data, {
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 2000 // 2s, then 4s, then 8s
      },
      removeOnComplete: true,
      removeOnFail: false,
      ...options
    });
  },

  /**
   * Pushes a bulk SMS campaign task to the campaigns processing queue
   */
  async addCampaignJob(data) {
    return campaignQueue.add('processCampaign', data, {
      attempts: 1,
      removeOnComplete: true,
      removeOnFail: false
    });
  },

  /**
   * Pushes an incoming DLR webhook task to the background DLR queue
   */
  async addDlrJob(data) {
    return dlrQueue.add('processDlr', data, {
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 1000
      },
      removeOnComplete: true,
      removeOnFail: false
    });
  }
};

