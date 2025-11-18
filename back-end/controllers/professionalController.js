const jwt = require('jsonwebtoken');
const Driver = require('../models/Driver');
const Mechanic = require('../models/Mechanic');
const { logActivity } = require('../services/activityLogService');
const { sendOtpViaWhatsApp } = require('../services/otpService');

// GET /api/professional/status
// Unified status endpoint for both drivers and mechanics (no top-level role preference)
exports.checkStatus = async (req, res) => {
    try {
        const header = req.headers.authorization;
        if (!header) return res.status(401).json({ message: 'Authorization token required' });
        const token = header.replace('Bearer ', '').trim();

        let decoded;
        try {
            decoded = jwt.verify(token, process.env.JWT_SECRET);
        } catch (e) {
            return res.status(401).json({ message: 'Invalid or expired token' });
        }

        if (!decoded?.id || (!decoded?.role && !decoded?.roles)) {
            return res.status(401).json({ message: 'Invalid token payload' });
        }

        // Normalize roles array
        const roles = Array.isArray(decoded.roles) ? decoded.roles : [decoded.role];
        const response = { roles, requiresTokenRefresh: false };

        // Process driver role
        if (roles.includes('driver')) {
            const driverId = decoded.role === 'driver' ? decoded.id : decoded.driverId; // backward compat
            if (driverId) {
                const driver = await Driver.findById(driverId).select('personal_info.registration_status adminActions isVerified updatedAt');
                if (driver) {
                    const recentActions = (driver.adminActions || [])
                        .filter(a => Date.now() - new Date(a.timestamp).getTime() < 7 * 24 * 60 * 60 * 1000)
                        .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

                    response.driver = {
                        id: driver._id,
                        registrationStatus: driver.personal_info?.registration_status || 'uncertain',
                        isVerified: !!driver.isVerified,
                        lastAdminAction: recentActions[0] || null,
                        lastUpdate: recentActions[0]?.timestamp || driver.updatedAt,
                        wsEndpoint: process.env.NODE_ENV === 'production'
                            ? `wss://${req.headers.host}/ws/driver`
                            : `ws://${req.headers.host}/ws/driver`
                    };
                } else {
                    response.driver = { error: 'not_found' };
                }
            }
        }

        // Process mechanic role
        // Process mechanic role
        if (roles.includes('mechanic')) {
            const mechanicId = decoded.role === 'mechanic' ? decoded.id : decoded.mechanicId; // backward compat
            if (mechanicId) {
                const mech = await Mechanic.findById(mechanicId)
                    .select('registrationStatus servicesOffered updatedAt'); // removed isVerified

                if (mech) {
                    response.mechanic = {
                        id: mech._id,
                        registrationStatus: mech.registrationStatus || 'uncertain', // use DB field only
                        servicesCount: (mech.servicesOffered || []).length,
                        lastUpdate: mech.updatedAt,
                        wsEndpoint: process.env.NODE_ENV === 'production'
                            ? `wss://${req.headers.host}/ws/mechanic`
                            : `ws://${req.headers.host}/ws/mechanic`
                    };
                } else {
                    response.mechanic = { error: 'not_found' };
                }
            }
        }


        // Token refresh logic (if <1h)
        if (decoded.exp && (decoded.exp - Date.now() / 1000) < 3600) {
            const payload = { id: decoded.id, role: decoded.role, roles };
            if (decoded.mechanicId) payload.mechanicId = decoded.mechanicId;
            if (decoded.driverId) payload.driverId = decoded.driverId;
            const newToken = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '240h' });
            response.token = newToken;
            response.requiresTokenRefresh = true;
        }

        return res.status(200).json(response);
    } catch (e) {
        return res.status(500).json({ message: 'Server error checking status' });
    }
};
// POST /api/auth/verify-otp-unified
exports.verifyOtpUnified = async (req, res) => {
    try {
        const { phoneNumber, otp } = req.body;
        if (!phoneNumber || !otp) {
            return res.status(400).json({ message: 'phoneNumber & otp required' });
        }

        // Try finding user in Mechanic first
        let mech = await Mechanic.findOne({ phoneNumber }).select('+otp +otpExpiresAt registrationStatus');
        let driver = await Driver.findOne({ phoneNumber }).select('+otp personal_info.registration_status');

        // If no user exists
        if (!mech && !driver) return res.status(404).json({ message: 'No OTP requested' });

        // Validate OTP for whichever exists
        const validOtp =
            (mech && mech.otp === otp && mech.otpExpiresAt.getTime() > Date.now()) ||
            (driver && driver.otp === otp);

        if (!validOtp) return res.status(401).json({ message: 'Invalid or expired OTP' });

        // Clear OTPs
        if (mech) {
            mech.otp = undefined;
            mech.otpExpiresAt = undefined;
            await mech.save();
            await logActivity({
                action: 'MECHANIC_LOGIN',
                description: `Mechanic ${mech._id} logged in`,
                entityType: 'mechanic',
                entityId: mech._id,
                performedBy: mech._id,
                userType: 'Mechanic'
            });
        }

        if (driver) {
            driver.otp = undefined;
            driver.isVerified = true;
            await driver.save();
            await logActivity({
                action: 'DRIVER_LOGIN',
                description: `Driver ${driver._id} logged in`,
                entityType: 'driver',
                entityId: driver._id,
                performedBy: driver._id,
                userType: 'Driver'
            });
        }

        // Determine roles
        const roles = [];
        if (mech) roles.push('mechanic');
        if (driver) roles.push('driver');

        // Build token payload
        const payload = {
            id: mech?._id || driver._id,
            roles,
            mechanicId: mech?._id,
            driverId: driver?._id,
            mechanicRegistrationStatus: mech?.registrationStatus || 'uncertain',
            driverRegistrationStatus: driver?.personal_info?.registration_status || 'uncertain'
        };

        const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '240h' });

        return res.status(200).json({
            message: 'OTP verified',
            token,
            roles,
            mechanicRegistrationStatus: payload.mechanicRegistrationStatus,
            driverRegistrationStatus: payload.driverRegistrationStatus
        });
    } catch (e) {
        return res.status(500).json({ message: 'Server error' });
    }
};


// Utility to generate OTP
function generateOTP() {
    return Math.floor(10000 + Math.random() * 90000);
}


// Unified OTP sender
exports.sendOTPUnified = async (req, res) => {
    try {
        const { phoneNumber } = req.body;

        // Validate input
        if (!phoneNumber) {
            return res.status(400).json({ message: 'phoneNumber is required' });
        }

        // Check both Driver and Mechanic collections
        const driver = await Driver.findOne({ phoneNumber });
        const mechanic = await Mechanic.findOne({ phoneNumber });

        // If not found in either collection
        if (!driver && !mechanic) {
            return res.status(404).json({ message: 'User not found. Please register first.' });
        }

        // Generate OTP with 5 min expiry
        const otp = generateOTP();
        const otpExpiresAt = new Date(Date.now() + 5 * 60 * 1000);

        const updatedRoles = [];

        // Update OTP for Driver if found
        if (driver) {
            await Driver.updateOne(
                { phoneNumber },
                { $set: { otp, otpExpiresAt, isVerified: false } }
            );
            updatedRoles.push('Driver');
        }

        // Update OTP for Mechanic if found
        if (mechanic) {
            await Mechanic.updateOne(
                { phoneNumber },
                { $set: { otp, otpExpiresAt, isVerified: false } }
            );
            updatedRoles.push('Mechanic');
        }

        // Send OTP via WhatsApp
        await sendOtpViaWhatsApp(phoneNumber, otp);


        // NOTE: replace with actual SMS integration (Twilio, etc.)
        return res.status(200).json({
            message: 'OTP sent',
            roles: updatedRoles // return all roles found for this phone
        });

    } catch (err) {
        return res.status(500).json({ message: 'Server error' });
    }
};
