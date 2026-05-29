const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String, required: true, select: false },
    role: { type: String, enum: ['user', 'moderator', 'admin'], default: 'user', index: true },
    banned: { type: Boolean, default: false },
    bannedAt: { type: Date, default: null },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

userSchema.index({ role: 1, banned: 1 });

module.exports = mongoose.model('User', userSchema);
