const jwt = require('jsonwebtoken');
const Admin = require('../models/Admin');
const { logActivity } = require('../services/activityLogService');

exports.adminLogin = async (req, res) => {
    const { username, password } = req.body;

    try {
        // Validate input
        if (!username || !password) {
            return res.status(400).json({
                success: false,
                message: 'Username and password are required'
            });
        }

        const admin = await Admin.findOne({ username });
        if (!admin) {
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials'
            });
        }

        if (!admin.active) {
            return res.status(403).json({
                success: false,
                message: 'Account is inactive. Please contact the superadmin.'
            });
        }

        const isMatch = await admin.comparePassword(password);
        if (!isMatch) {
            return res.status(401).json({
                success: false,
                message: 'Invalid credentials'
            });
        }

        // Generate token with admin data
        const token = jwt.sign(
            {
                id: admin._id,
                username: admin.username,
                role: admin.role,
                active: admin.active
            },
            process.env.JWT_SECRET,
            { expiresIn: '8h' }
        );

        // Log activity
        await logActivity({
            action: 'ADMIN_LOGIN',
            description: `Admin ${username} logged in`,
            entityType: 'admin',
            entityId: admin._id,
            performedBy: admin._id,
            userType: 'Admin'
        });

        res.status(200).json({
            success: true,
            token,
            user: {
                id: admin._id,
                username: admin.username,
                role: admin.role,
                 active: admin.active
            },
            message: 'Login successful'
        });
    } catch (error) {
        await logActivity({
            action: 'ADMIN_LOGIN_ERROR',
            description: error.message,
            metadata: { username },
            isError: true,
            errorDetails: error.stack
        });
        res.status(500).json({
            success: false,
            message: 'Server error during login'
        });
    }
};

exports.createFirstAdmin = async (req, res) => {
    try {
        const existingAdmin = await Admin.findOne();
        if (existingAdmin) {
            return res.status(400).json({
                success: false,
                message: 'Admin already exists'
            });
        }

        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({
                success: false,
                message: 'Username and password are required'
            });
        }

        const admin = new Admin({
            username,
            password,
            role: 'superadmin',
            active: true
        });
        await admin.save();

        await logActivity({
            action: 'CREATE_FIRST_ADMIN',
            description: `First admin account created: ${username}`,
            entityType: 'admin',
            entityId: admin._id,
            performedBy: admin._id,
            userType: 'Admin'
        });

        res.status(201).json({
            success: true,
            message: 'First admin created successfully'
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: 'Server error during account creation'
        });
    }
};