const jwt = require('jsonwebtoken');
const Driver = require('../models/Driver');
const Mechanic = require('../models/Mechanic');
const { logActivity } = require('../services/activityLogService');
const { generateOTPWithExpiry, sendOtpViaWhatsApp } = require('../services/otpService');

/**
 * Send OTP to driver for authentication.
 * @route POST /api/driver/auth/send-otp
 * @access Public
 */
exports.sendDriverOTP = async (req, res) => {
  const { phoneNumber } = req.body;
  if (!phoneNumber) {
    return res.status(400).json({ message: 'Phone number required' });
  }
  try {
    const { otp, expiresAt } = generateOTPWithExpiry();
    await Driver.findOneAndUpdate(
      { phoneNumber },
      {
        otp,
        otpExpiresAt: expiresAt,
        isVerified: false
      },
      { upsert: true, new: true }
    );
    await sendOtpViaWhatsApp(phoneNumber, otp);
    res.status(200).json({
      message: 'OTP sent'
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
};

/**
 * Verify driver OTP and issue JWT token.
 * @route POST /api/driver/auth/verify-otp
 * @access Public
 */
exports.verifyDriverOTP = async (req, res) => {
  const { phoneNumber, otp } = req.body;
  if (!phoneNumber || !otp) {
    return res.status(400).json({ message: 'Phone and OTP required' });
  }
  try {
    const driver = await Driver.findOne({ phoneNumber }).select('+otp +otpExpiresAt');
    if (!driver) {
      return res.status(404).json({ message: 'No OTP requested' });
    }
    if (driver.otp !== otp) {
      return res.status(401).json({ message: 'Invalid OTP' });
    }
    if (driver.otpExpiresAt < new Date()) {
        return res.status(401).json({ message: 'OTP has expired.' });
    }
    driver.isVerified = true;
    driver.otp = undefined;
    driver.otpExpiresAt = undefined;
    await driver.save();
    await logActivity({
      action: 'DRIVER_LOGIN',
      description: `Driver ${driver._id} logged in`,
      entityType: 'driver',
      entityId: driver._id,
      performedBy: driver._id,
      userType: 'Driver'
    });
    let roles = ['driver'];
    let mechanicId = null;
    try {
      const Mechanic = require('../models/Mechanic');
      const mech = await Mechanic.findOne({ phoneNumber }).select('_id');
      if (mech) { roles.push('mechanic'); mechanicId = mech._id; }
    } catch (_) { /* ignore */ }
    const tokenPayload = {
      id: driver._id,
      role: 'driver',
      roles,
      registrationStatus: driver.personal_info?.registration_status || 'pending'
    };
    if (mechanicId) tokenPayload.mechanicId = mechanicId;
    const token = jwt.sign(tokenPayload, process.env.JWT_SECRET, { expiresIn: '240h' });
    res.status(200).json({
      message: 'OTP verified',
      token,
      roles,
      registrationStatus: tokenPayload.registrationStatus
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
};

const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes

/**
 * Retrieve the profile of the authenticated driver.
 * @route GET /api/driver/profile
 * @access Private (Driver)
 */
exports.getDriverProfile = async (req, res) => {
  try {
    const driver = await Driver.findById(req.driver.id);
    if (!driver) {
      return res.status(404).json({ message: 'Driver not found' });
    }
    res.status(200).json(driver);
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
};

// Token refresh endpoint
// Enhanced token refresh with sliding expiration
exports.refreshToken = async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.status(401).json({ message: 'Token required' });
    const decoded = jwt.decode(token);
    if (!decoded || !decoded.id) return res.status(401).json({ message: 'Invalid token' });
    const driver = await Driver.findById(decoded.id);
    if (!driver) return res.status(404).json({ message: 'Driver not found' });
    // Re-evaluate roles
    let roles = ['driver'];
    let mechanicId = decoded.mechanicId || null;
    try {
      if (!mechanicId) {
        const Mechanic = require('../models/Mechanic');
        const mech = await Mechanic.findOne({ phoneNumber: driver.phoneNumber }).select('_id');
        if (mech) { roles.push('mechanic'); mechanicId = mech._id; }
      } else {
        roles = decoded.roles || ['driver','mechanic'];
      }
    } catch (_) { /* ignore */ }
    const newToken = jwt.sign({
      id: driver._id,
      role: 'driver',
      roles,
      mechanicId,
      registrationStatus: driver.personal_info.registration_status
    }, process.env.JWT_SECRET, { expiresIn: '240h' });
    res.status(200).json({
      token: newToken,
      roles,
      registrationStatus: driver.personal_info.registration_status
    });
  } catch (error) {
    res.status(401).json({ message: 'Token refresh failed' });
  }
};

exports.checkDriverStatus = async (req, res) => {
  try {
    // First verify the token to get the driver ID
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ message: 'Authorization token required' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (!decoded || !decoded.id) {
      return res.status(401).json({ message: 'Invalid token' });
    }

    const driver = await Driver.findById(decoded.id)
      .select('personal_info.registration_status adminActions');

    if (!driver) {
      return res.status(404).json({ message: 'Driver not found' });
    }

    // Check for recent admin actions (last 7 days)
    const recentActions = driver.adminActions
      .filter(action =>
        new Date() - action.timestamp < 7 * 24 * 60 * 60 * 1000
      )
      .sort((a, b) => b.timestamp - a.timestamp);

    // Prepare response
    const response = {
      registrationStatus: driver.personal_info.registration_status,
      lastUpdate: recentActions[0]?.timestamp || null,
      requiresTokenRefresh: false,
      wsEndpoint: process.env.NODE_ENV === 'production'
        ? `wss://${req.headers.host}/ws/driver`
        : `ws://${req.headers.host}/ws/driver`
    };

    // Check if token is about to expire (within 1 hour)
    if (decoded.exp && (decoded.exp - Date.now()/1000) < 3600) {
      const newToken = jwt.sign(
        {
          id: decoded.id,
          role: 'driver',
          registrationStatus: driver.personal_info.registration_status
        },
        process.env.JWT_SECRET,
        { expiresIn: '240h' }
      );
      response.token = newToken;
      response.requiresTokenRefresh = true;
    }

    res.status(200).json(response);
  } catch (error) {
    res.status(500).json({
      message: 'Server error checking status',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};