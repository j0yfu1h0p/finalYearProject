// routes/rateRoutes.js
const express = require("express");
const router = express.Router();
const rateController = require("../controllers/rateController");
const adminAuth = require('../middleware/adminAuth');
const roleCheck = require('../middleware/roleCheck');

// Public route to calculate price
router.post("/calculate", rateController.calculatePrice);

// Superadmin routes for managing rates
router.post("/", adminAuth, roleCheck(['superadmin']), rateController.createRate);
router.get("/", adminAuth, roleCheck(['superadmin']), rateController.getAllRates);
router.put("/:id", adminAuth, roleCheck(['superadmin']), rateController.updateRate);
router.delete("/:id", adminAuth, roleCheck(['superadmin']), rateController.deleteRate);

module.exports = router;
