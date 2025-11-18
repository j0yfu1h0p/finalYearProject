const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const { authenticateToken } = require('../middleware/auth');

// Get chat history for a trip
router.get('/history/:tripId', authenticateToken, chatController.getChatHistory);

// Send a message via API
router.post('/send', authenticateToken, chatController.sendMessage);

module.exports = router;