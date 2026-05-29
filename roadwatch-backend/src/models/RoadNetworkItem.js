const mongoose = require('mongoose');

const roadNetworkItemSchema = new mongoose.Schema(
  {
    id: { type: String, required: true, unique: true },
    name: { type: String, required: true },
    type: { type: String, default: 'MDR' },
    route: { type: String, required: true },
    districts: [{ type: String }],
    lengthKm: { type: Number, default: 0 },
    year: { type: Number, default: 0 },
    contractor: { type: String, default: '' },
    budgetCrore: { type: Number, default: 0 },
    condition: { type: String, default: 'Moderate' },
    issues: [{ type: String }],
    summary: { type: String, default: '' },
  },
  { timestamps: true },
);

module.exports = mongoose.model('RoadNetworkItem', roadNetworkItemSchema);
