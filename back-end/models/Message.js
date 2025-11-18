const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
    sender: {
        type: mongoose.Schema.Types.ObjectId,
        refPath: 'senderModel',
        required: true
    },
    senderModel: {
        type: String,
        required: true,
        enum: ['Customer', 'Driver', 'Mechanic']
    },
    message: {
        type: String,
        required: true
    },
    // Use refPath to dynamically reference either ServiceRequest or MechanicServiceRequest
    tripId: {
        type: mongoose.Schema.Types.ObjectId,
        refPath: 'tripModel',
        required: true
    },
    tripModel: {
        type: String,
        required: true,
        enum: ['ServiceRequest', 'MechanicServiceRequest']
    },
    timestamp: {
        type: Date,
        default: Date.now
    }
});

module.exports = mongoose.model('Message', messageSchema);