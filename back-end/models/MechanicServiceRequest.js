const mongoose = require('mongoose');

// Status flow: pending -> accepted -> arrived -> in-progress -> completed OR cancelled
const MECHANIC_REQUEST_STATUSES = ['pending','accepted','arrived','in-progress','completed','cancelled'];

const priceQuoteSchema = new mongoose.Schema({
  amount: { type: Number },
  currency: { type: String, default: 'PKR' },
  updatedAt: Date,
  providedAt: Date
}, { _id: false });

const mechanicServiceRequestSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', required: true, index: true },
  mechanicId: { type: mongoose.Schema.Types.ObjectId, ref: 'Mechanic', index: true },
  serviceType: { type: String, required: true },
  userLocation: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: {
      type: [Number], // [lng, lat]
      required: true,
      validate: {
        validator: v => Array.isArray(v) && v.length === 2 && v[0] >= -180 && v[0] <= 180 && v[1] >= -90 && v[1] <= 90,
        message: 'Invalid coordinates'
      }
    }
  },
  notes: { type: String, trim: true },
  status: { type: String, enum: MECHANIC_REQUEST_STATUSES, default: 'pending', index: true },
  priceQuote: priceQuoteSchema,
  cancellation: {
    cancelledBy: { type: String, enum: ['user','mechanic','system'] },
    reason: String,
    at: Date
  },
  expiresAt: { type: Date, index: true }, // logical expiry mark
}, { timestamps: true });

mechanicServiceRequestSchema.index({ userLocation: '2dsphere' });
mechanicServiceRequestSchema.index({ status: 1, createdAt: -1 });


module.exports = mongoose.model('MechanicServiceRequest', mechanicServiceRequestSchema);
