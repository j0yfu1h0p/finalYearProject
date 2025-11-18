

// routes/driverAuthRoutes.js
const express = require('express');
const router = express.Router();
const driverAuthController = require('../controllers/driverAuthController');
const authenticateDriver = require('../middleware/driverAuth');
router.post('/send-otp', driverAuthController.sendDriverOTP);
router.post('/verify-otp', driverAuthController.verifyDriverOTP);
router.get('/profile', driverAuthController.getDriverProfile);
router.post('/refresh-token', driverAuthController.refreshToken); // New endpoint
// router.get('/status', driverAuthController.checkDriverStatus);
router.get('/status', authenticateDriver, driverAuthController.checkDriverStatus);
module.exports = router;