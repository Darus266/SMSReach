exports.info = (message) => {
  console.log(`[INFO]  ${new Date().toISOString()} - ${message}`);
};

exports.warn = (message) => {
  console.warn(`[WARN]  ${new Date().toISOString()} - ${message}`);
};

exports.error = (message, err = '') => {
  console.error(`[ERROR] ${new Date().toISOString()} - ${message}`, err?.message || err);
};
