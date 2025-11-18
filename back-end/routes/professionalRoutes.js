const express = require('express');
const router = express.Router();
const professionalController = require('../controllers/professionalController');

// Unified status endpoint for both drivers and mechanics
router.get('/status', professionalController.checkStatus);
router.post('/auth/verify-otp-unified', professionalController.verifyOtpUnified);
router.post('/auth/send-otp-unified', professionalController.sendOTPUnified);
module.exports = router;

