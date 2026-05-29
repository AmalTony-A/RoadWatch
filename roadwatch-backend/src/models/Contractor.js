const mongoose = require('mongoose');

const contractorReviewSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    userId: { type: String, default: '' },
    userName: { type: String, default: 'Anonymous' },
    rating: { type: Number, default: 3 },
    sentiment: { type: String, default: 'neutral' },
    reviewText: { type: String, default: '' },
    emotionEmoji: { type: String, default: '😐' },
    timestamp: { type: String, default: '' },
    isSpamDetected: { type: Boolean, default: false },
    helpfulCount: { type: Number, default: 0 },
    imageUrl: { type: String, default: '' },
  },
  { _id: false },
);

const contractorSchema = new mongoose.Schema(
  {
    id: { type: String, required: true, unique: true },
    name: { type: String, required: true },
    company: { type: String, required: true },
    projectStatus: { type: String, default: 'Ongoing' },
    overallRating: { type: Number, default: 3.5 },
    totalReviews: { type: Number, default: 0 },
    reviews: { type: [contractorReviewSchema], default: [] },
    trustedBadge: { type: String, default: '' },
    publicTransparencyScore: { type: Number, default: 0 },
    complaintCount: { type: Number, default: 0 },
    roadsManaged: [{ type: String }],
    profileImageUrl: { type: String, default: '' },
  },
  { timestamps: true },
);

module.exports = mongoose.model('Contractor', contractorSchema);
