const mongoose = require('mongoose');

const aiUsageSchema = new mongoose.Schema(
  {
    category: {
      type: String,
      enum: ['chat', 'image'],
      required: true,
      index: true,
    },
    ownerKey: { type: String, required: true, index: true },
    cacheKey: { type: String, required: true, index: true, unique: true },
    response: { type: mongoose.Schema.Types.Mixed, required: true },
    expiresAt: { type: Date, required: true },
  },
  { timestamps: true },
);

aiUsageSchema.index({ ownerKey: 1, category: 1, createdAt: -1 });
aiUsageSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('AiUsage', aiUsageSchema);