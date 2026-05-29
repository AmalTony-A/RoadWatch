const mongoose = require('mongoose');

const roadSegmentSchema = new mongoose.Schema(
  {
    id: { type: String, required: true, unique: true },
    name: { type: String, required: true },
    ward: { type: String, required: true },
    polyline: [
      {
        lat: Number,
        lng: Number,
      },
    ],
    roadHealthScore: { type: Number, default: 50 },
    color: { type: String, default: 'yellow' },
    nearbyIssues: { type: Number, default: 0 },
    recentComplaints: { type: Number, default: 0 },
  },
  { timestamps: true },
);

module.exports = mongoose.model('RoadSegment', roadSegmentSchema);
