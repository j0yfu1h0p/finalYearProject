// controllers/userController.js
const Customer = require('../models/Customer');
const { logActivity } = require('../services/activityLogService');

/**
 * Retrieve the profile of the authenticated user.
 * @route GET /user/profile
 * @access Private (User)
 */
exports.getUserProfile = async (req, res) => {
    try {
        const user = await Customer.findById(req.user.id)
            .select('fullName phoneNumber -_id');

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        res.json({
            success: true,
            user: {
                name: user.fullName,
                phone: user.phoneNumber
            }
        });
    } catch (err) {
        await logActivity({
            action: 'GET_USER_PROFILE_ERROR',
            description: err.message,
            performedBy: req.user?.id,
            userType: 'User',
            isError: true,
            errorDetails: err.stack
        });
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
};

/**
 * Retrieve a user's profile by their user ID.
 * @route GET /user/:userId
 * @access Private (Admin/User)
 */
exports.getUserById = async (req, res) => {
    try {
        const { userId } = req.params;

        const user = await Customer.findById(userId)
            .select('fullName phoneNumber -_id');

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        res.json({
            success: true,
            user: {
                name: user.fullName,
                phone: user.phoneNumber
            }
        });
    } catch (err) {
        await logActivity({
            action: 'GET_USER_BY_ID_ERROR',
            description: err.message,
            performedBy: req.user?.id || req.admin?.id,
            userType: req.user ? 'User' : 'Admin',
            isError: true,
            errorDetails: err.stack,
            metadata: { targetUserId: req.params.userId }
        });
        res.status(500).json({
            success: false,
            message: 'Server error'
        });
    }
};
