const jwt = require('jsonwebtoken');
const Admin = require('../models/Admin');

const adminAuth = async (req, res, next) => {
    try {
        const token = req.header('Authorization')?.replace('Bearer ', '');
        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'No token provided, authorization denied'
            });
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET);

        const admin = await Admin.findById(decoded.id).select('-password');
        if (!admin) {
            return res.status(401).json({
                success: false,
                message: 'Token is not valid'
            });
        }

        if (!admin.active) {
            return res.status(403).json({
                success: false,
                message: 'Admin account is inactive'
            });
        }

        req.admin = {
            id: admin._id,
            username: admin.username,
            role: admin.role,
            active: admin.active
        };

        next();
    } catch (error) {
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({
                success: false,
                message: 'Token has expired, please log in again'
            });
        }

        return res.status(401).json({
            success: false,
            message: 'Token is not valid'
        });
    }
};

module.exports = adminAuth;
