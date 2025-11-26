const mongoose = require('mongoose');

const reviewSchema = new mongoose.Schema({
    serviceType: {
        type: String,
        enum: ['towing', 'mechanic'],
        required: true
    },
    requestId: {
        type: mongoose.Schema.Types.ObjectId,
        required: true,
        refPath: 'requestModel'
    },
    requestModel: {
        type: String,
        enum: ['ServiceRequest', 'MechanicServiceRequest'],
        required: true
    },
    reviewer: {
        type: mongoose.Schema.Types.ObjectId,
        refPath: 'reviewerModel',
        required: true
    },
    reviewerModel: {
        type: String,
        enum: ['Customer', 'Driver', 'Mechanic'],
        default: 'Customer',
        required: true
    },
    reviewee: {
        type: mongoose.Schema.Types.ObjectId,
        required: true,
        refPath: 'revieweeModel'
    },
    revieweeModel: {
        type: String,
        enum: ['Driver', 'Mechanic', 'Customer'],
        required: true
    },
    rating: {
        type: Number,
        min: 1,
        max: 5,
        required: true
    },
    comment: {
        type: String,
        trim: true,
        maxlength: 1000
    },
    rideEndedAt: {
        type: Date
    },
    metadata: {
        vehicleType: String,
        serviceCategory: String
    }
}, { timestamps: true });

reviewSchema.index({ requestId: 1, requestModel: 1, reviewer: 1, reviewerModel: 1 }, { unique: true });
reviewSchema.index({ reviewee: 1, revieweeModel: 1, createdAt: -1 });
reviewSchema.index({ reviewer: 1, createdAt: -1 });

module.exports = mongoose.model('Review', reviewSchema);
