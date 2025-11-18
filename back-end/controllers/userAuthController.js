const Customer = require('../models/Customer');
const jwt = require('jsonwebtoken');
const { logActivity } = require('../services/activityLogService');
const { generateOTPWithExpiry, sendOtpViaWhatsApp } = require('../services/otpService');
const logger = require('../utils/logger');

/**
 * Send OTP to user for authentication.
 * @route POST /api/user/auth/send-otp
 * @access Public
 */
exports.sendOTP = async (req, res) => {
    const { phoneNumber } = req.body;

    if (!phoneNumber) {
        return res.status(400).json({ message: 'Phone number is required.' });
    }

    try {
        logger.debug('Incoming user OTP request', { phoneNumber });
        const { otp, expiresAt } = generateOTPWithExpiry();

        // Upsert the OTP and its expiration (create or update existing record)
        await Customer.findOneAndUpdate(
            { phoneNumber },
            {
                otp: otp,
                otpExpiresAt: expiresAt,
                isVerified: false
            },
            { upsert: true, new: true }
        );

        // Send OTP via WhatsApp
        await sendOtpViaWhatsApp(phoneNumber, otp);
        logger.debug('OTP sent to user via WhatsApp', { phoneNumber });

        res.status(200).json({
            message: 'OTP sent successfully.'
        });

    } catch (error) {
        logger.error('User OTP send failed', error);
        res.status(500).json({ message: 'Server error sending OTP.' });
    }
};

/**
 * Verify user OTP and issue JWT token.
 * @route POST /api/user/auth/verify-otp
 * @access Public
 */
exports.verifyOTP = async (req, res) => {
    const { phoneNumber, otp } = req.body;

    if (!phoneNumber || !otp) {
        return res.status(400).json({ message: 'Phone number and OTP are required.' });
    }

    try {
        const customer = await Customer.findOne({ phoneNumber }).select('+otp +otpExpiresAt fullName');
        if (!customer) {
            return res.status(404).json({ message: 'No OTP requested for this number.' });
        }

        // Verify OTP first
        if (customer.otp !== otp) {
            return res.status(401).json({ message: 'Invalid OTP.' });
        }

        // Check for OTP expiration
        if (customer.otpExpiresAt < new Date()) {
            return res.status(401).json({ message: 'OTP has expired.' });
        }

        // Mark as verified (regardless of name status)
        customer.isVerified = true;
        customer.otp = undefined;
        customer.otpExpiresAt = undefined;
        await customer.save();

        await logActivity({
            action: 'USER_LOGIN',
            description: `User ${customer._id} logged in.`,
            performedBy: customer._id,
            userType: 'User',
            entityId: customer._id,
            entityType: 'customer'
        });

        // Generate JWT
        const token = jwt.sign({ id: customer._id }, process.env.JWT_SECRET, { expiresIn: '365d' });

        res.status(200).json({
            message: 'OTP verified successfully',
            token: token,
            customer: {
                id: customer._id,
                phoneNumber: customer.phoneNumber,
                fullName: customer.fullName
            },
            requiresFullName: !customer.fullName // If no fullName, requires full name
        });

    } catch (error) {
        await logActivity({
            action: 'USER_LOGIN_ERROR',
            description: error.message,
            metadata: { phoneNumber },
            isError: true,
            errorDetails: error.stack
        });
        res.status(500).json({ message: 'Server error verifying OTP' });
    }
};

/**
 * Submit or update user's full name after OTP verification.
 * @route POST /api/user/auth/submit-fullname
 * @access Private (User)
 */
exports.submitFullName = async (req, res) => {
    const { phoneNumber, fullName } = req.body;

    if (!phoneNumber || !fullName || fullName.trim().split(' ').length < 2) {
        return res.status(400).json({
            message: 'Valid phone number and full name (first and last) are required.'
        });
    }

    try {
        const customer = await Customer.findOne({ phoneNumber });
        if (!customer) {
            return res.status(400).json({ message: 'Please verify your phone number first.' });
        }

        // Update name
        customer.fullName = fullName.trim();
        await customer.save();

        await logActivity({
            action: 'SUBMIT_FULL_NAME',
            description: `User ${customer._id} submitted their full name.`,
            performedBy: customer._id,
            userType: 'User',
            entityId: customer._id,
            entityType: 'customer',
            metadata: { fullName: customer.fullName }
        });

        res.status(200).json({
            message: 'Full name updated successfully.',
            customer: {
                id: customer._id,
                phoneNumber: customer.phoneNumber,
                fullName: customer.fullName
            }
        });

    } catch (error) {
        await logActivity({
            action: 'SUBMIT_FULL_NAME_ERROR',
            description: error.message,
            performedBy: req.user?.id,
            userType: 'User',
            isError: true,
            errorDetails: error.stack
        });
        res.status(500).json({ message: 'Server error updating full name.' });
    }
};
