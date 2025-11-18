const mongoose = require('mongoose');

const customerSchema = new mongoose.Schema({
    phoneNumber: {
        type: String,
        required: true,
        unique: true,
        trim: true,
        // Adjust the regex to match international phone numbers with country codes
        // This regex matches a '+' followed by 1 or more digits (to accommodate country codes)
        match: /^\+\d+$/,
    },
    fullName: {
        type: String,
        trim: true
    },
    otp: { 
        type: String,
        select: false // Do not return OTP in queries by default
    },
    isVerified: {
        type: Boolean,
        default: false
    },
    createdAt: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('Customer', customerSchema);