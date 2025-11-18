const jwt = require('jsonwebtoken');
const Mechanic = require('../models/Mechanic');
const { logActivity } = require('../services/activityLogService');
const { generateOTPWithExpiry, sendOtpViaWhatsApp } = require('../services/otpService');

/**
 * Send OTP to mechanic for authentication.
 * @route POST /api/mechanic/auth/send-otp
 * @access Public
 */
exports.sendMechanicOTP = async (req, res) => {
  try {
    const { phoneNumber } = req.body;
    if (!phoneNumber) return res.status(400).json({ message: 'phoneNumber required' });

    const { otp, expiresAt } = generateOTPWithExpiry();

    await Mechanic.findOneAndUpdate(
      { phoneNumber },
      { $set: { otp, otpExpiresAt: expiresAt, isVerified: false } },
      { upsert: true, new: true }
    );

    await sendOtpViaWhatsApp(phoneNumber, otp);
    return res.status(200).json({ message: 'OTP sent' });
  } catch (e) {
    return res.status(500).json({ message: 'Server error' });
  }
};

/**
 * Verify mechanic OTP and issue JWT token.
 * @route POST /api/mechanic/auth/verify-otp
 * @access Public
 */
exports.verifyMechanicOTP = async (req, res) => {
    try {
        const { phoneNumber, otp } = req.body;
        if (!phoneNumber || !otp) {
            return res.status(400).json({ message: 'phoneNumber & otp required' });
        }

        // Select mechanic with OTP, OTP expiry, and registrationStatus
        const mech = await Mechanic.findOne({ phoneNumber })
            .select('+otp +otpExpiresAt registrationStatus');
        if (!mech) return res.status(404).json({ message: 'No OTP requested' });

        // Validate OTP
        if (!mech.otp || mech.otp !== otp) {
            return res.status(401).json({ message: 'Invalid OTP' });
        }

        if (mech.otpExpiresAt && mech.otpExpiresAt.getTime() < Date.now()) {
            return res.status(401).json({ message: 'OTP expired' });
        }

        // Clear OTP after successful verification
        mech.otp = undefined;
        mech.otpExpiresAt = undefined;
        await mech.save();

        // Log mechanic login activity
        await logActivity({
            action: 'MECHANIC_LOGIN',
            description: `Mechanic ${mech._id} logged in`,
            entityType: 'mechanic',
            entityId: mech._id,
            performedBy: mech._id,
            userType: 'Mechanic'
        });

        // Multi-role detection (check if driver exists with same phone)
        let roles = ['mechanic'];
        let driverId = null;
        let driverStatus = null;
        try {
            const Driver = require('../models/Driver');
            const drv = await Driver.findOne({ phoneNumber })
                .select('_id personal_info.registration_status');
            if (drv) {
                roles.push('driver');
                driverId = drv._id;
                driverStatus = drv.personal_info?.registration_status || 'uncertain';
            }
        } catch (_) { /* ignore */ }

        // Build token payload with statuses
        const tokenPayload = {
            id: mech._id,
            role: 'mechanic',
            roles,
            mechanicRegistrationStatus: mech.registrationStatus || 'uncertain'
        };

        if (driverId) {
            tokenPayload.driverId = driverId;
            tokenPayload.driverRegistrationStatus = driverStatus;
        }

        const token = jwt.sign(tokenPayload, process.env.JWT_SECRET, { expiresIn: '240h' });

        return res.status(200).json({
            message: 'OTP verified',
            token,
            roles,
            mechanicRegistrationStatus: mech.registrationStatus || 'uncertain',
            driverRegistrationStatus: driverStatus
        });
    } catch (e) {
        return res.status(500).json({ message: 'Server error' });
    }
};

/**
 * Refresh mechanic JWT token.
 * @route POST /api/mechanic/auth/refresh-token
 * @access Private (Mechanic)
 */
exports.refreshToken = async (req, res) => {
  try {
    const oldToken = req.headers.authorization?.replace('Bearer ', '');
    if (!oldToken) return res.status(401).json({ message: 'Token required' });

    const decoded = jwt.decode(oldToken);
    if (!decoded?.id) return res.status(401).json({ message: 'Invalid token' });

    const mech = await Mechanic.findById(decoded.id);
    if (!mech) return res.status(404).json({ message: 'Mechanic not found' });

    // Re-evaluate roles
    let roles = ['mechanic'];
    let driverId = decoded.driverId || null;
    try {
      if (!driverId) {
        const Driver = require('../models/Driver');
        const drv = await Driver.findOne({ phoneNumber: mech.phoneNumber }).select('_id');
        if (drv) { roles.push('driver'); driverId = drv._id; }
      } else {
        roles = decoded.roles || ['mechanic','driver'];
      }
    } catch(_) { /* ignore */ }

    const token = jwt.sign({ id: mech._id, role: 'mechanic', roles, driverId }, process.env.JWT_SECRET, { expiresIn: '240h' });
    return res.status(200).json({ token, roles });
  } catch (e) {
    return res.status(500).json({ message: 'Server error' });
  }
};
