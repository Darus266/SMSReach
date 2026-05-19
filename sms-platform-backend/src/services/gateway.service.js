const config = require('../config');
const logger = require('../utils/logger');
const routingService = require('./routing.service');

/**
 * Normalize Gateway Error Codes to standard enterprise-grade errors
 */
const normalizeError = (provider, statusCode, rawBody, errMessage = '') => {
  const lowercaseBody = JSON.stringify(rawBody).toLowerCase();
  
  let code = 'GATEWAY_ERROR';
  let message = errMessage || `Gateway error via ${provider}`;

  if (provider === 'twilio') {
    // Twilio typical error codes (e.g. 21608: Sandbox restriction, 21211: Invalid number, etc.)
    const twilioCode = rawBody?.code;
    if ([21211, 21212, 21213].includes(twilioCode) || lowercaseBody.includes('invalid')) {
      code = 'INVALID_RECIPIENT';
      message = 'The recipient phone number is invalid.';
    } else if ([21606, 21608, 21612].includes(twilioCode) || lowercaseBody.includes('whitelist') || lowercaseBody.includes('permission')) {
      code = 'SENDER_ID_REJECTED';
      message = 'The Sender ID is not approved or lacks permissions for this route.';
    } else if (statusCode === 401 || statusCode === 403) {
      code = 'GATEWAY_AUTH_FAILED';
      message = 'Authentication failed with Twilio Gateway.';
    } else if (statusCode === 429) {
      code = 'RATE_LIMIT_EXCEEDED';
      message = 'Twilio rate limit exceeded.';
    }
  } else if (provider === 'infobip') {
    // Infobip error structure: rawBody.requestError.serviceException.messageId
    const messageId = rawBody?.requestError?.serviceException?.messageId;
    if (messageId === 'UNAUTHORIZED' || statusCode === 401) {
      code = 'GATEWAY_AUTH_FAILED';
      message = 'Authentication failed with Infobip Gateway.';
    } else if (lowercaseBody.includes('invalid destination') || lowercaseBody.includes('missing to')) {
      code = 'INVALID_RECIPIENT';
      message = 'The recipient phone number is invalid.';
    } else if (lowercaseBody.includes('sender') || lowercaseBody.includes('from name')) {
      code = 'SENDER_ID_REJECTED';
      message = 'The Sender ID is invalid or rejected by carrier regulations.';
    } else if (statusCode === 429) {
      code = 'RATE_LIMIT_EXCEEDED';
      message = 'Infobip rate limit exceeded.';
    }
  }

  const normalized = new Error(message);
  normalized.code = code;
  normalized.statusCode = statusCode;
  normalized.raw = rawBody;
  normalized.provider = provider;
  return normalized;
};

/**
 * Pure REST SMS Gateway implementation via Native Fetch (No bloated SDKs)
 */
class GatewayService {
  
  /**
   * Helper to perform fetch requests with absolute timeouts
   */
  async _fetchWithTimeout(url, options, timeoutMs = 8000) {
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, { ...options, signal: controller.signal });
      clearTimeout(id);
      return response;
    } catch (err) {
      clearTimeout(id);
      if (err.name === 'AbortError') {
        const timeoutErr = new Error(`Connection timed out after ${timeoutMs}ms`);
        timeoutErr.code = 'GATEWAY_TIMEOUT';
        throw timeoutErr;
      }
      throw err;
    }
  }

  /**
   * Send SMS via Twilio
   */
  async sendViaTwilio(to, message, senderId) {
    const { accountSid, authToken } = config.gateways.twilio;
    
    // Fallback check if twilio credentials are empty
    if (!accountSid || !authToken || accountSid.startsWith('ACmock_')) {
      logger.warn('Twilio credentials not set or in mock mode. Falling back to local simulated delivery.');
      return this.sendViaMock(to, message, senderId);
    }

    const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
    const credentials = Buffer.from(`${accountSid}:${authToken}`).toString('base64');
    
    const params = new URLSearchParams();
    params.append('To', to);
    params.append('Body', message);
    params.append('From', senderId);

    logger.info(`Sending Twilio SMS to ${to} using Sender ID [${senderId}]`);

    const response = await this._fetchWithTimeout(url, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: params.toString()
    });

    const data = await response.json();

    if (!response.ok) {
      throw normalizeError('twilio', response.status, data, data?.message);
    }

    return {
      success: true,
      externalId: data.sid,
      status: 'SENT',
      provider: 'twilio'
    };
  }

  /**
   * Send SMS via Infobip
   */
  async sendViaInfobip(to, message, senderId) {
    const { baseUrl, apiKey } = config.gateways.infobip;

    if (!apiKey || apiKey.startsWith('mock_')) {
      logger.warn('Infobip credentials not set or in mock mode. Falling back to local simulated delivery.');
      return this.sendViaMock(to, message, senderId);
    }

    const cleanBaseUrl = baseUrl.replace(/^https?:\/\//, '');
    const url = `https://${cleanBaseUrl}/sms/2/text/advanced`;

    logger.info(`Sending Infobip SMS to ${to} using Sender ID [${senderId}]`);

    const payload = {
      messages: [
        {
          from: senderId,
          destinations: [{ to }],
          text: message
        }
      ]
    };

    const response = await this._fetchWithTimeout(url, {
      method: 'POST',
      headers: {
        'Authorization': `App ${apiKey}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    const data = await response.json();

    if (!response.ok) {
      throw normalizeError('infobip', response.status, data, data?.detail);
    }

    const msgResult = data?.messages?.[0];
    const statusGroup = msgResult?.status?.groupName;

    // Infobip distinct status validation (REJECTED represents carrier/regulatory blocks)
    if (statusGroup === 'REJECTED') {
      const err = new Error(msgResult.status.description || 'Infobip message rejected');
      err.code = 'SENDER_ID_REJECTED';
      err.provider = 'infobip';
      err.raw = data;
      throw err;
    }

    return {
      success: true,
      externalId: msgResult.messageId,
      status: 'SENT',
      provider: 'infobip'
    };
  }

  /**
   * Local Mock Gateway for testing and development fallback
   */
  async sendViaMock(to, message, senderId) {
    logger.info(`[GATEWAY MOCK] Dispatching SMS to ${to} | Sender ID: ${senderId} | Body: "${message}"`);
    
    // Simulate slight API network latency
    await new Promise(resolve => setTimeout(resolve, 300));

    // Force error triggers for testing if specific numbers are targeted
    if (to === '+33600000000') {
      const err = new Error('Mock error for invalid number');
      err.code = 'INVALID_RECIPIENT';
      err.provider = 'mock';
      throw err;
    }
    if (to === '+33611111111') {
      const err = new Error('Mock gateway server fail');
      err.code = 'GATEWAY_ERROR';
      err.provider = 'mock';
      throw err;
    }

    return {
      success: true,
      externalId: `mock-ext-${Math.random().toString(36).substring(2, 11)}`,
      status: 'SENT',
      provider: 'mock'
    };
  }

  /**
   * Unified interface with dynamic routing and automatic Failover (Fallback)
   */
  async sendWithFallback(to, message, senderId) {
    const primaryProvider = await routingService.selectProvider(to);
    let secondaryProvider = primaryProvider === 'twilio' ? 'infobip' : 'twilio';
    
    // If routing resolved mock, bypass fallbacks
    if (primaryProvider === 'mock') {
      return this.sendViaMock(to, message, senderId);
    }

    logger.info(`Routing SMS: Destination=${to} | Primary=${primaryProvider} | Secondary=${secondaryProvider}`);

    try {
      if (primaryProvider === 'twilio') {
        return await this.sendViaTwilio(to, message, senderId);
      } else {
        return await this.sendViaInfobip(to, message, senderId);
      }
    } catch (primaryError) {
      logger.error(`Primary gateway [${primaryProvider}] failed for ${to}. Attempting fallback...`, primaryError);

      // Attempt sending via the secondary fallback gateway
      try {
        if (secondaryProvider === 'twilio') {
          const res = await this.sendViaTwilio(to, message, senderId);
          logger.info(`Fallback SUCCESSFUL using Twilio for ${to}`);
          return res;
        } else {
          const res = await this.sendViaInfobip(to, message, senderId);
          logger.info(`Fallback SUCCESSFUL using Infobip for ${to}`);
          return res;
        }
      } catch (secondaryError) {
        logger.error(`Secondary fallback gateway [${secondaryProvider}] also failed for ${to}`);
        
        // Throw primary error to propagate initial failure context, but embed fallback details
        primaryError.message = `${primaryError.message} (Fallback gateway ${secondaryProvider} also failed: ${secondaryError.message})`;
        throw primaryError;
      }
    }
  }
}

module.exports = new GatewayService();
