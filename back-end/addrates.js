// seedRates.js
const mongoose = require("mongoose");
const Rate = require("./models/Rate");

// Connect to MongoDB
mongoose.connect("mongodb://127.0.0.1:27017/myautobridge_db", {
    useNewUrlParser: true,
    useUnifiedTopology: true
}).then(() => {})
    .catch(err => {});

// Dummy data for rates
const dummyRates = [
    {
        serviceType: "heavy_truck",
        basePrice: 1500,
        pricePerKm: 80
    },
    {
        serviceType: "two_wheeler",
        basePrice: 200,
        pricePerKm: 15
    },
    {
        serviceType: "four_wheeler",
        basePrice: 500,
        pricePerKm: 25
    },
    {
        serviceType: "car_lockout_service",
        basePrice: 1000,
        pricePerKm: 0
    },
    {
        serviceType: "puncture_repair",
        basePrice: 300,
        pricePerKm: 0
    },
    {
        serviceType: "battery_jump_start",
        basePrice: 700,
        pricePerKm: 0
    },
    {
        serviceType: "fuel_delivery",
        basePrice: 400,
        pricePerKm: 10
    },
    {
        serviceType: "quote_after_inspection",
        basePrice: 0,
        pricePerKm: 0
    }
];

// Insert dummy data
async function seedRates() {
    try {
        await Rate.deleteMany(); // clear existing data
        await Rate.insertMany(dummyRates);
        mongoose.connection.close();
    } catch (error) {
        mongoose.connection.close();
    }
}

seedRates();
