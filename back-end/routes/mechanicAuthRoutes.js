const express = require('express');
const router = express.Router();
const mechanicAuthController = require('../controllers/mechanicAuthController');

// Auth endpoints
router.post('/send-otp', mechanicAuthController.sendMechanicOTP);
router.post('/verify-otp', mechanicAuthController.verifyMechanicOTP);
router.post('/refresh-token', mechanicAuthController.refreshToken);

module.exports = router;
