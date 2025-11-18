const jwt = require('jsonwebtoken');
const Driver = require('../models/Driver');

/**
 * Auth middleware for driver-only JWT verification.
 * It ignores mechanic tokens completely.
 */
const driverAuth = async (req, res, next) => {
    try {
        // Extract token from Authorization header
        const token = req.header('Authorization')?.replace('Bearer ', '');
        if (!token) {
            return res.status(401).json({ message: 'No token, authorization denied' });
        }

        // Verify token using JWT secret
        const decoded = jwt.verify(token, process.env.JWT_SECRET);

        // Only proceed if token has driver role
        if (!decoded.roles?.includes('driver')) {
            return res.status(401).json({ message: 'Token does not belong to a driver' });
        }

        // Fetch driver from DB
        const driver = await Driver.findById(decoded.driverId || decoded.id);
        if (!driver) {
            return res.status(401).json({ message: 'Driver not found for this token' });
        }

        // Attach driver and payload to request object
        req.driver = driver;
        req.user = decoded;

        next();
    } catch (error) {
        res.status(401).json({ message: 'Token is not valid' });
    }
};

module.exports = driverAuth;
