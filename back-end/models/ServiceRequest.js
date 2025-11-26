const mongoose = require('mongoose');
const mongoosePaginate = require('mongoose-paginate-v2');

const ServiceRequestSchema = new mongoose.Schema({
    vehicleType: {
        type: String,
        required: true
    },
    pickupLocation: {
        address: {
            type: String,
            required: true
        },
        location: {
            type: {
                type: String,
                enum: ['Point'],
                required: true
            },
            coordinates: {
                type: [Number], // [longitude, latitude]
                required: true
            }
        }
    },
    destination: {
        address: {
            type: String,
            required: true
        },
        coordinates: {
            lat: {
                type: Number,
                required: true
            },
            lng: {
                type: Number,
                required: true
            }
        }
    },
    distance: {
        type: Number,
        required: true
    },
    duration: {
        type: Number,
        required: true
    },
    rate: {
        type: Number,
        required: true
    },
    totalAmount: {
        type: Number,
        required: true
    },
    status: {
        type: String,
        enum: ['pending', 'accepted', 'arrived', 'completed', 'cancelled', 'in_progress'],
        default: 'pending'
    },
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Customer',
        required: true
    },
    driverId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Driver'
    },
    reviewId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Review'
    },
    providerReviewId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Review'
    },
    completedAt: {
        type: Date
    },
    expiresAt: {
        type: Date
    }
}, {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true }
});

ServiceRequestSchema.plugin(mongoosePaginate);

ServiceRequestSchema.index({ 'pickupLocation.location': '2dsphere' });
ServiceRequestSchema.index({ userId: 1, createdAt: -1 });
ServiceRequestSchema.index({ status: 1, expiresAt: 1 });
ServiceRequestSchema.index({ driverId: 1 });

module.exports = mongoose.model('ServiceRequest', ServiceRequestSchema);
