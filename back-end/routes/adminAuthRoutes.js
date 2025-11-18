
const express = require('express');
const router = express.Router();
const adminAuthController = require('../controllers/adminAuthController');

router.post('/login', adminAuthController.adminLogin);
router.post('/create-first-admin', adminAuthController.createFirstAdmin);

module.exports = router;