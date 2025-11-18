const mongoose = require('mongoose');
const { encryptField, decryptField } = require('../utils/crypto');

const SERVICES = [
    "car_lockout_service",
    "puncture_repair",
    "battery_jump_start",
    "fuel_delivery",
    "quote_after_inspection"
];

const REGISTRATION_STATUS = {
    UNCERTAIN: 'uncertain',
    PENDING: 'pending',
    APPROVED: 'approved',
    REJECTED: 'rejected'
};

const mechanicSchema = new mongoose.Schema({
    phoneNumber: {
        type: String,
        required: true,
        unique: true,
        match: /^\+92[3][0-9]{9}$/
    },
    personName: {
        type: String,
        required: true
    },
    shopName: {
        type: String,
        required: true
    },
    otp: { type: String, select: false },
    otpExpiresAt: { type: Date, select: false },
    personalPhotoUrl: String,
    cnicPhotoUrl: String, // Added CNIC photo field
    workshopPhotoUrl: String,
    introductionVideoUrl: String,
    registrationCertificateUrl: String,
    emergencyContact: {
        type: String,
        // set: v => (v ? encryptField(v) : v),
        // get: v => (v ? decryptField(v) : v)
    },
    servicesOffered: [{
        type: String,
        enum: SERVICES
    }],
    location: {
        type: {
            type: String,
            enum: ['Point'],
            default: 'Point'
        },
        coordinates: {
            type: [Number],
            default: [0, 0]
        }
    },
    address: String, // Added address field for the text address
    role: {
        type: String,
        enum: ['mechanic'],
        default: 'mechanic'
    },
    registrationStatus: {
        type: String,
        enum: Object.values(REGISTRATION_STATUS),
        default: REGISTRATION_STATUS.UNCERTAIN
    },
    isActive: { type: Boolean, default: true },
    createdAt: { type: Date, default: Date.now }
}, { toJSON: { getters: true }, toObject: { getters: true } });

mechanicSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('Mechanic', mechanicSchema);
module.exports.SERVICES = SERVICES;
module.exports.REGISTRATION_STATUS = REGISTRATION_STATUS;