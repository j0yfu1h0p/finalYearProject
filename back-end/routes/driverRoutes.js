// routes/driverRoutes.js
const express = require('express');
const router = express.Router();
const driverController = require('../controllers/driverController');
const authMiddleware = require('../middleware/driverAuth');
const {authenticateToken} = require("../middleware/auth"); // Assuming you have an auth middleware
const {profileMiddlewareGetByID} = require("../middleware/profileMiddleware");
// Register driver (requires auth)
router.post('/register', authMiddleware, driverController.registerDriver);

// Get driver profile (requires auth)
router.get('/profile', authMiddleware, driverController.getDriverProfile);


router.get('/:id/profile', profileMiddlewareGetByID, driverController.getDriverProfileByID);
// Get pending updates (requires auth)
router.get('/updates', authenticateToken, driverController.getPendingUpdates);

// Check if CNIC exists
router.get('/check-cnic', driverController.checkCNIC);

// Check if License exists
router.get('/check-license', driverController.checkLicense);

// Check if Plate exists
router.get('/check-plate', driverController.checkPlate);

// Get nearby pending service requests for a driver
router.post('/nearby-requests', authMiddleware, driverController.getNearbyPendingRequests);

// NEW: Get active trip for driver (for restoration on app open)
router.get('/active-trip', authMiddleware, require('../controllers/serviceController').getActiveDriverTrip);

module.exports = router;
