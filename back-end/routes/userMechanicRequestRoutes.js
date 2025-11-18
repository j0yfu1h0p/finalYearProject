const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const c = require('../controllers/mechanicServiceRequestController');

// User-focused mechanic service request routes
router.post('/', authenticateToken, c.createUserServiceRequest);
router.get('/', authenticateToken, c.listUserServiceRequests);
router.get('/active', authenticateToken, c.getActiveMechanicRequest); // NEW: Check for active mechanic request
router.get('/:id', authenticateToken, c.getUserServiceRequest);
router.patch('/:id/cancel', authenticateToken, c.cancelUserServiceRequest);

module.exports = router;
