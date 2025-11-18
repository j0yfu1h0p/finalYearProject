const express = require('express');
const router = express.Router();

const { authenticateToken,authenticateUserToken  } = require('../middleware/auth'); // user auth
const mechanicAuth = require('../middleware/mechanicAuth'); // mechanic auth
const c = require('../controllers/mechanicServiceRequestController');

// ORDER MATTERS: specific paths first

// Mechanic: get nearby pending requests
router.get('/pending/nearby', mechanicAuth, c.getNearbyPendingMechanicServiceRequests);

// NEW: Check for active mechanic job (mechanic side) - MUST BE BEFORE /:id
router.get('/active-job', mechanicAuth, c.getActiveMechanicJob);

// USER ROUTES
router.post('/', authenticateToken, c.createUserServiceRequest);                // Create new request
router.get('/', authenticateToken, c.listUserServiceRequests);                 // List user requests for mechanic only

// NEW: Check for active mechanic request (user side) - BOTH paths for compatibility
router.get('/user/active', authenticateToken, c.getActiveMechanicRequest);     // User app crash recovery
router.get('/active-request', authenticateToken, c.getActiveMechanicRequest);  // Alternative path

router.get('/:id', authenticateToken, c.getUserServiceRequest);                // Get specific request
router.patch('/:id/cancel', authenticateToken, c.cancelUserServiceRequest);    // Cancel pending request
router.get('/user/requests/history', authenticateUserToken, c.listUserServiceRequests); // for user only
// MECHANIC ROUTES
router.patch('/:id/accept', mechanicAuth, c.acceptMechanicServiceRequest);           // Accept request
router.patch('/:id/status', mechanicAuth, c.updateMechanicServiceRequestStatus);     // Update status

module.exports = router;
