exports.selectProvider = async (phoneNumber) => {
  // Route based on international prefix (E.164 format)
  if (phoneNumber.startsWith('+225')) return 'infobip'; // Ivory Coast
  if (phoneNumber.startsWith('+221')) return 'infobip'; // Senegal
  if (phoneNumber.startsWith('+237')) return 'infobip'; // Cameroon
  if (phoneNumber.startsWith('+242')) return 'infobip'; // Congo
  if (phoneNumber.startsWith('+33'))  return 'twilio';  // France
  if (phoneNumber.startsWith('+44'))  return 'twilio';  // UK
  if (phoneNumber.startsWith('+1'))   return 'twilio';  // USA/Canada
  return 'mock'; // Fallback for unsupported countries during development
};
