const ServiceRequest = require('../models/ServiceRequest');
const Customer = require('../models/Customer');
const Driver = require('../models/Driver');
const { logActivity } = require('../services/activityLogService');

/**
 * Retrieve ride history for a user with optional status filter and pagination.
 * @route GET /history/user
 * @access Private (User)
 */
exports.getRideHistoryUser = async (req, res) => {
    try {
        const userId = req.user.id;
        const { page = 1, limit = 10, status } = req.query;

        // Build filter for query
        const filter = { userId };
        if (status) filter.status = status;

        // Pagination and population options
        const options = {
            page: parseInt(page),
            limit: parseInt(limit),
            sort: { createdAt: -1 },
            populate: [
                {
                    path: 'userId',
                    select: 'phoneNumber',
                    model: Customer
                },
                {
                    path: 'driverId',
                    select: 'phoneNumber vehicle', // Add the fields you want from Driver
                    model: Driver
                }
            ]
        };

        // Fetch ride history
        const history = await ServiceRequest.paginate(filter, options);

        await logActivity({
            action: 'GET_USER_RIDE_HISTORY',
            description: `User ${userId} fetched their ride history.`,
            performedBy: userId,
            userType: 'User',
            metadata: { query: req.query }
        });

        res.status(200).json({
            success: true,
            data: history
        });
    } catch (error) {
        await logActivity({
            action: 'GET_USER_RIDE_HISTORY_ERROR',
            description: error.message,
            performedBy: req.user.id,
            userType: 'User',
            isError: true,
            errorDetails: error.stack
        });
        res.status(500).json({
            success: false,
            message: 'Server error fetching ride history'
        });
    }
};

/**
 * Retrieve ride history for a driver with optional status filter and pagination.
 * @route GET /history/driver
 * @access Private (Driver)
 */
exports.getRideHistoryDriver = async (req, res) => {
    let driverId;
    try {
        if (req.driver?.driverId) {
            driverId = req.driver.driverId;
        }
        else if (req.driver?._id) {
            driverId = req.driver._id;
        }
        else if (req.driver?.id) {
            driverId = req.driver.id;
        }
        else if (req.user?.id) {
            driverId = req.user.id;
        }
        else {
            return res.status(401).json({
                success: false,
                message: 'Driver authentication required - no driver ID found'
            });
        }

        const { page = 1, limit = 10, status } = req.query;

        const filter = {
            $or: [
                { driverId: driverId },
                { driver: driverId } // Some databases might use 'driver' instead of 'driverId'
            ]
        };
        if (status) filter.status = status;

        // Pagination and population options
        const options = {
            page: parseInt(page),
            limit: parseInt(limit),
            sort: { createdAt: -1 },
            populate: [
                {
                    path: 'userId',
                    select: 'phoneNumber',
                    model: Customer
                },
                {
                    path: 'driverId',
                    select: 'phoneNumber vehicle',
                    model: Driver
                }
            ]
        };

        // Fetch ride history
        const history = await ServiceRequest.paginate(filter, options);

        await logActivity({
            action: 'GET_DRIVER_RIDE_HISTORY',
            description: `Driver ${driverId} fetched their ride history.`,
            performedBy: driverId,
            userType: 'Driver',
            metadata: { query: req.query }
        });

        res.status(200).json({
            success: true,
            data: history
        });
    } catch (error) {
        await logActivity({
            action: 'GET_DRIVER_RIDE_HISTORY_ERROR',
            description: error.message,
            performedBy: driverId || req.driver?.id || req.user?.id,
            userType: 'Driver',
            isError: true,
            errorDetails: error.stack
        });
        res.status(500).json({
            success: false,
            message: 'Server error fetching ride history'
        });
    }
};