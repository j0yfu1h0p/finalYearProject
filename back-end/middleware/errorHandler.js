const logger = require('../utils/logger');

const errorHandler = (err, req, res, next) => {
    const statusCode = err.statusCode || err.status || res.statusCode || 500;
    const message = err.message || 'Server error';
    logger.captureError(res, err, {
        controller: req.route?.path,
        method: req.method
    });
    logger.error('Unhandled request error', {
        method: req.method,
        url: req.originalUrl,
        statusCode,
        body: req.body,
        params: req.params,
        query: req.query,
        error: err
    });
    res.status(statusCode).json({ message });
};

module.exports = errorHandler;
