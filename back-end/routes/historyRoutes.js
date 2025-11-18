const express = require('express');
const router = express.Router();
const historyController = require('../controllers/historyController');
const { authenticateToken } = require('../middleware/auth');
const authMiddleware = require('../middleware/driverAuth');
const driverController = require("../controllers/driverController");


router.get('/', authenticateToken, historyController.getRideHistoryUser);
router.get('/driver', authenticateToken, historyController.getRideHistoryDriver);

module.exports = router;