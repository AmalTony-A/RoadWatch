const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true },
    description: { type: String, required: true, trim: true },
    category: {
      type: String,
      enum: ['Pothole', 'Waterlogging', 'Damaged road', 'Traffic issue', 'Street light issue', 'Other'],
      required: true,
    },
    image: { type: String, default: '' },
    images: { type: [String], default: [] },
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true },
    status: { type: String, enum: ['Pending', 'In Progress', 'Resolved'], default: 'Pending', index: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    roadId: { type: String, default: '' },
    address: { type: String, default: '' },
    imagePublicId: { type: String, default: '' },
    authorityTicket: { type: String, default: 'PENDING' },
    recommendedDepartment: { type: String, default: 'Municipal Corporation' },
    routingReason: { type: String, default: '' },
    complaintLetter: { type: String, default: '' },
    sentToAuthority: { type: Boolean, default: false },
    deliveredToAuthority: { type: Boolean, default: false },
    readByAuthority: { type: Boolean, default: false },
    sentAt: { type: Date },
    deliveredAt: { type: Date },
    readAt: { type: Date },
    timeline: { type: [mongoose.Schema.Types.Mixed], default: [] },
  },
  { timestamps: true },
);

reportSchema.index({ status: 1, category: 1, createdAt: -1 });
reportSchema.index({ userId: 1, createdAt: -1 });
reportSchema.index({ latitude: 1, longitude: 1 });

reportSchema.virtual('location').get(function getLocation() {
  return {
    lat: this.latitude,
    lng: this.longitude,
    address: this.address,
  };
});

reportSchema.virtual('imageUrl').get(function getImageUrl() {
  return this.image;
});

reportSchema.set('toJSON', { virtuals: true });
reportSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Report', reportSchema);
