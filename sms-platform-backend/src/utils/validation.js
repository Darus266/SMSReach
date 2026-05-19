const Joi = require('joi');

exports.registerSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(6).required(),
  companyName: Joi.string().min(2).max(100).required()
});

exports.loginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().required()
});

exports.sendSmsSchema = Joi.object({
  to: Joi.string().pattern(/^\+?[1-9]\d{1,14}$/).required().messages({
    'string.pattern.base': '"to" must be a valid E.164 phone number (e.g. +33612345678)'
  }),
  message: Joi.string().min(1).max(1600).required(),
  senderId: Joi.string().min(3).max(11).alphanum().required().messages({
    'string.alphanum': '"senderId" must be alphanumeric only (GSM standard)'
  })
});

exports.createCampaignSchema = Joi.object({
  name: Joi.string().min(3).max(100).required(),
  senderId: Joi.string().min(3).max(11).alphanum().required(),
  messageBody: Joi.string().min(1).max(1600).required(),
  scheduledAt: Joi.date().iso().greater('now').optional()
});

exports.requestSenderIdSchema = Joi.object({
  name: Joi.string().min(3).max(11).alphanum().required()
});

exports.approveSenderIdSchema = Joi.object({
  senderId: Joi.string().uuid().required()
});

exports.depositSchema = Joi.object({
  amount: Joi.number().precision(4).positive().required()
});

exports.sendCampaignSchema = Joi.object({
  recipients: Joi.array().items(
    Joi.string().pattern(/^\+?[1-9]\d{1,14}$/).required().messages({
      'string.pattern.base': 'Each recipient must be a valid E.164 phone number (e.g. +33612345678)'
    })
  ).min(1).required()
});

