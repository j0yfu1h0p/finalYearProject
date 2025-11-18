// controllers/rateController.js
const Rate = require("../models/Rate");
const { logActivity } = require('../services/activityLogService');

// Calculate price for a given service type
exports.calculatePrice = async (req, res) => {
    try {
        const { serviceType, distanceKm } = req.body;

        // Validate required fields
        if (!serviceType) {
            return res.status(400).json({ error: "Service type is required" });
        }

        // Fetch rate for the given service type
        const rate = await Rate.findOne({ serviceType });
        if (!rate) {
            return res.status(404).json({ error: "Rate not found for this service type" });
        }

        let totalPrice;

        // Case 1: Car lockout service is always flat price
        if (serviceType === "car_lockout_service") {
            totalPrice = rate.basePrice;
        }
        // Case 2: Distance-based pricing
        else if (rate.pricePerKm && rate.pricePerKm > 0) {
            if (!distanceKm || distanceKm <= 0) {
                return res.status(400).json({
                    error: "This service requires a valid distanceKm"
                });
            }
            totalPrice = rate.basePrice + (distanceKm * rate.pricePerKm);
        }
        // Case 3: Flat price, no distance required
        else {
            totalPrice = rate.basePrice;
        }

        // Send response
        res.json({
            serviceType,
            totalPrice,
            distanceKm: rate.pricePerKm > 0 && serviceType !== "car_lockout_service" ? distanceKm : null
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

// Create a new rate
exports.createRate = async (req, res) => {
    try {
        const { serviceType, basePrice, pricePerKm } = req.body;

        // Basic validation
        if (!serviceType || !basePrice) {
            return res.status(400).json({ error: "Service type and base price are required." });
        }

        // Check if rate for this service type already exists
        const existingRate = await Rate.findOne({ serviceType });
        if (existingRate) {
            return res.status(409).json({ error: `A rate for ${serviceType} already exists.` });
        }

        const newRate = new Rate({ serviceType, basePrice, pricePerKm });
        await newRate.save();

        await logActivity({
            action: 'CREATE_RATE',
            description: `Admin created a new rate for ${serviceType}`,
            performedBy: req.admin.id,
            userType: 'Admin',
            metadata: { rate: newRate }
        });

        res.status(201).json({ message: "Rate created successfully", rate: newRate });
    } catch (err) {
        await logActivity({
            action: 'CREATE_RATE_ERROR',
            description: err.message,
            performedBy: req.admin.id,
            userType: 'Admin',
            isError: true,
            errorDetails: err.stack
        });
        res.status(500).json({ error: err.message });
    }
};

// Get all rates
exports.getAllRates = async (req, res) => {
    try {
        const rates = await Rate.find();
        res.json(rates);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
};

// Update a rate
exports.updateRate = async (req, res) => {
    try {
        const { id } = req.params;
        const { basePrice, pricePerKm } = req.body;

        const rate = await Rate.findById(id);
        if (!rate) {
            return res.status(404).json({ error: "Rate not found." });
        }

        if (basePrice) rate.basePrice = basePrice;
        if (pricePerKm !== undefined) rate.pricePerKm = pricePerKm;

        await rate.save();

        await logActivity({
            action: 'UPDATE_RATE',
            description: `Admin updated rate for ${rate.serviceType}`,
            performedBy: req.admin.id,
            userType: 'Admin',
            entityId: rate._id,
            entityType: 'rate',
            metadata: { updatedFields: req.body }
        });

        res.json({ message: "Rate updated successfully", rate });
    } catch (err) {
        await logActivity({
            action: 'UPDATE_RATE_ERROR',
            description: err.message,
            performedBy: req.admin.id,
            userType: 'Admin',
            entityId: req.params.id,
            entityType: 'rate',
            isError: true,
            errorDetails: err.stack
        });
        res.status(500).json({ error: err.message });
    }
};

// Delete a rate
exports.deleteRate = async (req, res) => {
    try {
        const { id } = req.params;
        const rate = await Rate.findByIdAndDelete(id);

        if (!rate) {
            return res.status(404).json({ error: "Rate not found." });
        }

        await logActivity({
            action: 'DELETE_RATE',
            description: `Admin deleted rate for ${rate.serviceType}`,
            performedBy: req.admin.id,
            userType: 'Admin',
            entityId: rate._id,
            entityType: 'rate'
        });

        res.json({ message: "Rate deleted successfully" });
    } catch (err) {
        await logActivity({
            action: 'DELETE_RATE_ERROR',
            description: err.message,
            performedBy: req.admin.id,
            userType: 'Admin',
            entityId: req.params.id,
            entityType: 'rate',
            isError: true,
            errorDetails: err.stack
        });
        res.status(500).json({ error: err.message });
    }
};
