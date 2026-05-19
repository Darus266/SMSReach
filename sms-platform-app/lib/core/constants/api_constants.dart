class ApiConstants {
  // Use 10.0.2.2 standard IP to connect from Android Emulator to localhost backend
  static const String baseUrl = 'http://10.0.2.2:3000/api/v1';

  // Endpoint segments
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  
  static const String smsSend = '/sms/send';
  static const String smsHistory = '/sms/history';
  
  static const String campaigns = '/campaigns';
  static const String senderIds = '/sender-ids';
  static const String wallet = '/billing/wallet';
  static const String deposit = '/billing/deposit';
  
  // Mobile Money & Invoice endpoints
  static const String initializePayment = '/billing/payments/initialize';
  static const String invoices = '/billing/payments/invoices';
  static const String autoRecharge = '/billing/payments/auto-recharge';
}
