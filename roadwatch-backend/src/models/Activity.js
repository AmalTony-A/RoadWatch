const mongoose = require('mongoose');

const activitySchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    action: { type: String, required: true, trim: true },
    details: { type: String, default: '', trim: true },
    meta: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

activitySchema.index({ createdAt: -1 });
activitySchema.index({ action: 1, createdAt: -1 });

module.exports = mongoose.models.Activity || mongoose.model('Activity', activitySchema);
