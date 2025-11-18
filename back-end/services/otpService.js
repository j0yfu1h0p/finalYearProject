const OTP_EXPIRATION_MINUTES = 5;
const whatsappService = require('./whatsappService');
const logger = require('../utils/logger');

exports.generateOTP = () => {
    return Math.floor(10000 + Math.random() * 90000).toString();
};

exports.generateOTPWithExpiry = () => {
    const otp = Math.floor(10000 + Math.random() * 90000).toString();
    const expiresAt = new Date(Date.now() + OTP_EXPIRATION_MINUTES * 60 * 1000);
    return { otp, expiresAt };
};

exports.sendOTP = async (phoneNumber, otp) => {

};

exports.sendOtpViaWhatsApp = async (phoneNumber, otp) => {
    const message = `Your MyAutoBridge OTP is: ${otp}`;
    try {
        logger.debug('Dispatching OTP via WhatsApp', { phoneNumber });
        await whatsappService.sendMessage(phoneNumber, message);
        logger.debug('OTP dispatched via WhatsApp', { phoneNumber });
    } catch (error) {
        logger.error('Failed to send OTP via WhatsApp', error);
        throw error;
    }
};
