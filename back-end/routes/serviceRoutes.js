const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const authenticateDriver = require('../middleware/driverAuth');
const serviceController = require('../controllers/serviceController');
const { getNearbyPendingRequests } = require("../controllers/driverController");
const reviewController = require('../controllers/reviewController');

// Create service request
router.route('/')
  .post(authenticateToken, serviceController.createServiceRequest);

// Get user's requests
router.route('/my')
  .get(authenticateToken, serviceController.getUserRequests);

// Get active ride for user (for restoration on app open)
router.route('/active-ride')
  .get(authenticateToken, serviceController.getActiveRide);

// Get pending requests (for drivers/admins)
router.route('/pool')
  .get(authenticateToken, serviceController.getPendingRequests);

router.post('/nearby-requests', authenticateToken, serviceController.getNearbyPendingRequests);

// Driver reviews customer after completing ride
router.post('/:id/user-review', authenticateDriver, reviewController.createDriverReviewForUser);


// Get specific request by ID
router.route('/:id')
  .get(authenticateToken, serviceController.getServiceRequestById);

// Submit review for completed ride
router.route('/:id/review')
  .post(authenticateToken, reviewController.createTowingReview);

// Cancel request - for customers
router.route('/:id/cancel')
  .patch(authenticateToken, serviceController.cancelServiceRequest);

// Driver accepts request
router.route('/:id/accept')
  .patch(authenticateDriver, serviceController.acceptServiceRequest);

// Driver completes request
router.route('/:id/complete')
  .patch(authenticateDriver, serviceController.completeServiceRequest);

// Driver cancels request
router.route('/:id/driver-cancel')
  .patch(authenticateDriver, serviceController.cancelServiceRequest);
router.route('/:id/arrived')
  .patch(authenticateDriver, serviceController.markArrived);

router.route('/:id/start')
  .patch(authenticateDriver, serviceController.startTrip);

// Driver completes request
router.route('/:id/complete')
  .patch(authenticateDriver, serviceController.completeServiceRequest);
module.exports = router;