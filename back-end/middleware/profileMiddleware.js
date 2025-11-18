// middleware/auth.js
const jwt = require('jsonwebtoken');

// Authentication middleware with debug logs
const profileMiddlewareGetByID = (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

        if (!token) {
            return res.status(401).json({ success: false, message: 'Access token required' });
        }

        // Verify token only
        jwt.verify(token, process.env.JWT_SECRET);
        next();
    } catch (error) {
        if (error.name === 'JsonWebTokenError') {
            return res.status(403).json({ success: false, message: 'Invalid token' });
        }

        if (error.name === 'TokenExpiredError') {
            return res.status(403).json({ success: false, message: 'Token expired' });
        }

        res.status(500).json({ success: false, message: 'Server error' });
    }
};

module.exports = { profileMiddlewareGetByID };
