exports.validate = (schema, property = 'body') => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req[property], { abortEarly: false });
    if (error) {
      const details = error.details.map(d => d.message).join(', ');
      return res.status(400).json({
        success: false,
        message: `Validation Error: ${details}`,
        timestamp: new Date().toISOString()
      });
    }
    // Replace req parameters with validated and parsed values
    req[property] = value;
    next();
  };
};
