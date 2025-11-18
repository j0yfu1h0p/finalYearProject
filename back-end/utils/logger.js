const util = require('util');

const LEVELS = {
    error: 'ERROR',
    warn: 'WARN',
    info: 'INFO',
    debug: 'DEBUG'
};

const isDebugEnabled = () => {
    if (process.env.ENABLE_DEBUG_LOGS) {
        return process.env.ENABLE_DEBUG_LOGS === 'true';
    }
    return process.env.NODE_ENV !== 'production';
};

const formatMeta = (meta) => {
    if (!meta) return '';
    if (meta instanceof Error) {
        return `\n${meta.stack || meta.message}`;
    }
    return `\n${util.inspect(meta, { depth: null, colors: false })}`;
};

const log = (level, message, meta) => {
    if (level === 'debug' && !isDebugEnabled()) {
        return;
    }

    const timestamp = new Date().toISOString();
    const tag = LEVELS[level] || 'LOG';
    const base = `[${timestamp}] [${tag}] ${message}`;

    if (meta) {
        console.log(base + formatMeta(meta));
    } else {
        console.log(base);
    }
};

const info = (message, meta) => log('info', message, meta);
const warn = (message, meta) => log('warn', message, meta);
const error = (message, meta) => log('error', message, meta);
const debug = (message, meta) => log('debug', message, meta);

const captureError = (res, error, context = {}) => {
    if (!res) return;
    res.locals = res.locals || {};
    if (error) {
        res.locals.__lastError = error;
        res.locals.__lastErrorMessage = error.message || res.locals.__lastErrorMessage;
    }
    if (context && Object.keys(context).length) {
        res.locals.__errorContext = { ...(res.locals.__errorContext || {}), ...context };
    }
};

const responseObserverMiddleware = (req, res, next) => {
    const originalJson = res.json.bind(res);
    res.json = (body) => {
        if (res.statusCode >= 400) {
            res.locals = res.locals || {};
            if (body && typeof body === 'object') {
                res.locals.__lastErrorMessage = body.message || body.error || res.locals.__lastErrorMessage;
            }
        }
        return originalJson(body);
    };
    return next();
};

const requestLoggerMiddleware = (req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
        const duration = Date.now() - start;
        const meta = {
            duration,
            ip: req.ip,
            userAgent: req.get?.('user-agent'),
            context: res.locals?.__errorContext,
            error: res.locals?.__lastError,
            message: res.locals?.__lastErrorMessage
        };
        const logLine = `HTTP ${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms`;
        if (res.statusCode >= 500) {
            error(logLine, meta);
        } else if (res.statusCode >= 400) {
            warn(logLine, meta);
        } else if (isDebugEnabled()) {
            debug(logLine, meta);
        }
    });

    next();
};

module.exports = {
    info,
    warn,
    error,
    debug,
    isDebugEnabled,
    requestLoggerMiddleware,
    responseObserverMiddleware,
    captureError
};
