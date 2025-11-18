const Mechanic = require('../models/Mechanic');
const { validateMechanicProfile } = require('../utils/validators');
const { decryptField } = require('../utils/crypto');
const MechanicServiceRequest = require('../models/MechanicServiceRequest');
const { logActivity } = require('../services/activityLogService');

/**
 * Create or update mechanic profile (initial fill).
 * @route POST /api/mechanic/profile
 * @access Private (Mechanic)
 */
exports.createProfile = async (req, res) => {
    try {
        // Validate request body
        const { error, value } = validateMechanicProfile(req.body, { partial: false });
        if (error) {
            return res.status(400).json({ message: error.details[0].message });
        }

        // Fields allowed to be updated
        const updateFields = [
            'personName', 'shopName', 'personalPhotoUrl', 'cnicPhotoUrl',
            'workshopPhotoUrl', 'introductionVideoUrl', 'emergencyContact',
            'registrationCertificateUrl', 'servicesOffered', 'location', 'address'
        ];
        const update = {};

        // Build update object only with defined fields
        updateFields.forEach(f => { if (value[f] !== undefined) update[f] = value[f]; });

        // Set registration status to pending when profile is created
        update.registrationStatus = 'pending';

        // Update mechanic in database
        const mechanic = await Mechanic.findByIdAndUpdate(
            req.mechanic._id,
            { $set: update },
            { new: true, runValidators: true } // Run validators for safety
        );
        if (!mechanic) {
            return res.status(404).json({ message: 'Mechanic not found' });
        }

        await logActivity({
            action: 'CREATE_MECHANIC_PROFILE',
            description: `Mechanic ${mechanic._id} created their profile.`,
            performedBy: mechanic._id,
            userType: 'Mechanic',
            entityId: mechanic._id,
            entityType: 'mechanic'
        });

        return res.status(200).json({
            message: 'Profile saved',
            profile: mechanic
        });
    } catch (e) {
        await logActivity({
            action: 'CREATE_MECHANIC_PROFILE_ERROR',
            description: e.message,
            performedBy: req.mechanic?._id,
            userType: 'Mechanic',
            isError: true,
            errorDetails: e.stack
        });
        return res.status(500).json({
            message: 'Server error',
            error: process.env.NODE_ENV === 'development' ? e.message : undefined
        });
    }
};

/**
 * Get recent bookings for a mechanic with pagination.
 * @route GET /api/mechanic/bookings/recent
 * @access Private (Mechanic)
 */
exports.getMechanicRecentBookings = async (req, res) => {
    try {
        const mechanicId = req.mechanic._id;
        const { limit = 10, page = 1 } = req.query;
        const skip = (parseInt(page) - 1) * parseInt(limit);

        // Fetch bookings where both mechanic and user exist
        const bookings = await MechanicServiceRequest.find({
            mechanicId: { $exists: true, $ne: null }, // Ensure mechanicId exists
            userId: { $exists: true, $ne: null },     // Ensure userId exists
            $or: [
                { mechanicId: mechanicId }, // Assigned bookings
                { mechanicId: { $exists: false }, status: 'pending' } // Not assigned but status pending
            ]
        })
            .populate('userId', 'phoneNumber name') // Populate user phone number and name
            .populate('mechanicId', 'phoneNumber name') // Populate mechanic phone number and name
            .sort({ createdAt: -1 })
            .limit(parseInt(limit))
            .skip(skip);

        // Count total for pagination
        const total = await MechanicServiceRequest.countDocuments({
            mechanicId: { $exists: true, $ne: null },
            userId: { $exists: true, $ne: null },
            $or: [
                { mechanicId: mechanicId },
                { mechanicId: { $exists: false }, status: 'pending' }
            ]
        });

        await logActivity({
            action: 'GET_MECHANIC_BOOKINGS',
            description: `Mechanic ${mechanicId} fetched recent bookings.`,
            performedBy: mechanicId,
            userType: 'Mechanic',
            metadata: { query: req.query }
        });

        res.json({
            success: true,
            bookings,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total,
                pages: Math.ceil(total / parseInt(limit))
            }
        });
    } catch (error) {
        await logActivity({
            action: 'GET_MECHANIC_BOOKINGS_ERROR',
            description: error.message,
            performedBy: req.mechanic?._id,
            userType: 'Mechanic',
            isError: true,
            errorDetails: error.stack
        });
        res.status(500).json({
            success: false,
            message: 'Error fetching mechanic bookings',
            error: error.message
        });
    }
};

/**
 * Get recent bookings for a user with pagination.
 * @route GET /api/user/bookings/recent
 * @access Private (User)
 */
exports.getUserRecentBookings = async (req, res) => {
    try {
        const userId = req.user._id; // Assuming you have user auth middleware
        const { limit = 10, page = 1 } = req.query;
        const skip = (parseInt(page) - 1) * parseInt(limit);

        const bookings = await MechanicServiceRequest.find({
            userId: userId
        })
            .populate('mechanicId', 'personName shopName phoneNumber') // Populate mechanic details
            .sort({ createdAt: -1 })
            .limit(parseInt(limit))
            .skip(skip);

        const total = await MechanicServiceRequest.countDocuments({
            userId: userId
        });

        await logActivity({
            action: 'GET_USER_MECHANIC_BOOKINGS',
            description: `User ${userId} fetched recent mechanic bookings.`,
            performedBy: userId,
            userType: 'User',
            metadata: { query: req.query }
        });

        res.json({
            success: true,
            bookings,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total,
                pages: Math.ceil(total / parseInt(limit))
            }
        });
    } catch (error) {
        await logActivity({
            action: 'GET_USER_MECHANIC_BOOKINGS_ERROR',
            description: error.message,
            performedBy: req.user?._id,
            userType: 'User',
            isError: true,
            errorDetails: error.stack
        });
        res.status(500).json({
            success: false,
            message: 'Error fetching user bookings',
            error: error.message
        });
    }
};

/**
 * Retrieve the profile of the authenticated mechanic.
 * @route GET /api/mechanic/profile
 * @access Private (Mechanic)
 */
exports.getProfile = async (req, res) => {
    try {
        // Find mechanic by ID and select only required fields
        const mechanic = await Mechanic.findById(req.mechanic._id).select(
            'personName shopName phoneNumber personalPhotoUrl cnicPhotoUrl workshopPhotoUrl introductionVideoUrl registrationCertificateUrl emergencyContact servicesOffered location address registrationStatus isActive createdAt'
        );
        if (!mechanic) {
            return res.status(404).json({ message: 'Mechanic profile not found' });
        }
        const mechanicObj = mechanic.toObject();
        return res.status(200).json({
            message: 'Profile fetched successfully',
            data: mechanicObj
        });
    } catch (error) {
        return res.status(500).json({ message: 'Server error' });
    }
};

/**
 * Retrieve mechanic profile by ID.
 * @route GET /api/mechanic/:id
 * @access Public
 */
exports.getMechanicProfile = async (req, res) => {
    try {
        const { id } = req.params;
        // Validate if ID is a valid ObjectId
        if (!id || !id.match(/^[0-9a-fA-F]{24}$/)) {
            return res.status(400).json({ error: 'Invalid mechanic ID format' });
        }
        // Fetch mechanic profile (excluding sensitive fields like otp)
        const mechanic = await Mechanic.findById(id).select('-otp -otpExpiresAt');
        if (!mechanic) {
            return res.status(404).json({ error: 'Mechanic not found' });
        }
        res.status(200).json({ success: true, data: mechanic });
    } catch (err) {
        res.status(500).json({ error: 'Server error' });
    }
};

/**
 * Update mechanic profile (partial update).
 * @route PUT /api/mechanic/profile
 * @access Private (Mechanic)
 */
exports.updateProfile = async (req, res) => {
  try {
    const { error, value } = validateMechanicProfile(req.body, { partial: true });
    if (error) return res.status(400).json({ message: error.details[0].message });
    const updateFields = [
      'personalPhotoUrl', 'workshopPhotoUrl', 'introductionVideoUrl',
      'emergencyContact', 'registrationCertificateUrl', 'servicesOffered', 'location', 'isActive'
    ];
    const update = {};
    updateFields.forEach(f => { if (value[f] !== undefined) update[f] = value[f]; });
    const mechanic = await Mechanic.findByIdAndUpdate(
      req.mechanic._id,
      { $set: update },
      { new: true }
    );

    await logActivity({
        action: 'UPDATE_MECHANIC_PROFILE',
        description: `Mechanic ${mechanic._id} updated their profile.`,
        performedBy: mechanic._id,
        userType: 'Mechanic',
        entityId: mechanic._id,
        entityType: 'mechanic',
        metadata: { updatedFields: Object.keys(update) }
    });

    return res.status(200).json({ message: 'Profile updated', profile: mechanic });
  } catch (e) {
    await logActivity({
        action: 'UPDATE_MECHANIC_PROFILE_ERROR',
        description: e.message,
        performedBy: req.mechanic?._id,
        userType: 'Mechanic',
        isError: true,
        errorDetails: e.stack
    });
    return res.status(500).json({ message: 'Server error' });
  }
};
