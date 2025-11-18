const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const { getUserProfile, getUserById } = require('../controllers/userController');

// Get current user's profile
router.get('/profile', authenticateToken, getUserProfile);

// Get user by ID (for searching other users)
router.get('/:userId', authenticateToken, getUserById);

module.exports = router;