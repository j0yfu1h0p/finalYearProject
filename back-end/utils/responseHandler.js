const jwt = require('jsonwebtoken');

exports.successResponse = (res, data, status = 200) => {
  res.status(status).json({
    success: true,
    ...data
  });
};

exports.errorResponse = (res, message, status = 400) => {
  res.status(status).json({
    success: false,
    error: message
  });
};

exports.createToken = (userId) => {
  return jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    expiresIn: '7d'
  });
};

exports.verifyToken = (token) => {
  return jwt.verify(token, process.env.JWT_SECRET);
};