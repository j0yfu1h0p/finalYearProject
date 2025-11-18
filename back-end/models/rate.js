// models/Rate.js
const mongoose = require("mongoose");

// Define schema for service rates
const rateSchema = new mongoose.Schema({
    serviceType: {
        type: String,
        enum: [
            "heavy_truck",
            "two_wheeler",
            "four_wheeler",
            "car_lockout_service",
            "puncture_repair",
            "battery_jump_start",
            "fuel_delivery",
            "quote_after_inspection"
        ],
        required: true,
        unique: true
    },
    basePrice: { type: Number, required: true },
    pricePerKm: { type: Number } // optional for services like lockout where distance may not matter
}, { timestamps: true });

module.exports = mongoose.model("Rate", rateSchema);
