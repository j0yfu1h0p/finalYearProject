const express = require('express');
const router = express.Router();
const authController = require('../controllers/userAuthController');
const { authenticateToken } = require('../middleware/auth');

router.post('/send-otp', authController.sendOTP);
router.post('/verify-otp', authController.verifyOTP);
router.post('/submit-name', authController.submitFullName);


module.exports = router;