const mongoose = require('mongoose');

const activityLogSchema = new mongoose.Schema({
  action: {
    type: String,
    required: true
  },
  description: String,
  entityType: {
    type: String,
    enum: ['driver', 'customer', 'request', 'admin', 'mechanic'] // added mechanic
  },
  entityId: mongoose.Schema.Types.ObjectId,
  performedBy: {
    type: mongoose.Schema.Types.ObjectId,
    refPath: 'userType'
  },
  userType: {
    type: String,
    required: true,
    enum: ['Admin', 'User', 'Driver', 'Mechanic']
  },
  metadata: {
    type: Object
  },
  isError: {
    type: Boolean,
    default: false
  },
  errorDetails: {
    type: String
  },
  timestamp: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('ActivityLog', activityLogSchema);