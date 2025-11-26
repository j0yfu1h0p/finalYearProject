
const mongoose = require('mongoose');

const vehicleSchema = new mongoose.Schema({
  vehicle_type: String,
  company_model: String,
  color: String,
  number_plate: String,
  manufacturing_year: String,
  vehicle_photo_url: String,
  registration_front_url: String,
  registration_back_url: String,
  verified: { type: Boolean, default: false }
});

const driverSchema = new mongoose.Schema({
  phoneNumber: {
    type: String,
    required: true,
    unique: true,
    match: /^\+92\d{10}$/,
  },
  otp: {
    type: String,
    select: false
  },
  isVerified: {
    type: Boolean,
    default: false
  },
  personal_info: {
    first_name: String,
    last_name: String,
    date_of_birth: Date,
    email: String,
    profile_photo_url: String,
    registration_status: {
      type: String,
      enum: ["uncertain", "pending", "approved", "rejected"],
      default: "uncertain"
    },
    registration_date: { type: Date, default: Date.now },
    last_updated: { type: Date, default: Date.now }
  },
  identification: {
    cnic_number: String,
    cnic_front_url: String,
    cnic_back_url: String,
    verified: { type: Boolean, default: false }
  },
  license: {
    license_number: String,
    license_photo_url: String,
    expiry_date: Date,
    verified: { type: Boolean, default: false }
  },
  vehicles: [vehicleSchema],
  rating: {
    type: Number,
    default: 0
  },
  ratingCount: {
    type: Number,
    default: 0
  },
  lastReviewAt: { type: Date }
}, { timestamps: true });

// Add adminActions to the schema
// Update the adminActions schema to be more flexible
driverSchema.add({
  adminActions: [{
    action: {
      type: String,
      enum: ['approved', 'rejected', 'updated'],
      required: true
    },
    adminId: {
      type: mongoose.Schema.Types.Mixed,  // Accepts both String and ObjectId
      required: true
    },
    adminType: {  // New field to distinguish between system and user admins
      type: String,
      enum: ['system', 'user'],
      default: 'user'
    },
    timestamp: {
      type: Date,
      default: Date.now
    },
    notes: {
      type: String,
      trim: true
    }
  }]
});

module.exports = mongoose.model('Driver', driverSchema);
