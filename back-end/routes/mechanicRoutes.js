const express = require('express');
const router = express.Router();
const mechanicController = require('../controllers/mechanicController');
const mechanicAuth = require('../middleware/mechanicAuth');

router.post('/profile', mechanicAuth, mechanicController.createProfile);
router.get('/profile', mechanicAuth, mechanicController.getProfile);
router.put('/profile', mechanicAuth, mechanicController.updateProfile);
router.get('/:id', mechanicController.getMechanicProfile);

// New routes for recent bookings
router.get('/bookings/recent', mechanicAuth, mechanicController.getMechanicRecentBookings);

// User routes (you might want to put this in a separate userRoutes file)
// router.get('/user/bookings/recent', userAuth, mechanicController.getUserRecentBookings);

module.exports = router;
