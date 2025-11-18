const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  phone: {
    type: String,
    required: true,
    unique: true,
    match: [/^\+92\d{10}$/, 'Please use a valid Pakistani phone number']
  },
  role: {
    type: String,
    enum: ['customer', 'driver', 'admin'],
    required: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

// Discriminator key for inheritance
userSchema.set('discriminatorKey', 'role');

module.exports = mongoose.model('User', userSchema);