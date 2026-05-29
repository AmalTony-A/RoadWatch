const mongoose = require('mongoose');

const budgetSchema = new mongoose.Schema(
  {
    roadId: { type: String, required: true, index: true },
    projectId: { type: String, required: true },
    allocatedInr: { type: Number, required: true },
    spentInr: { type: Number, required: true },
    contractor: { type: String, required: true },
    lastRepairDate: { type: String, required: true },
    expectedScore: { type: Number, default: 0 },
    actualScore: { type: Number, default: 0 },
    transparencyNote: { type: String, default: '' },
  },
  { timestamps: true },
);

module.exports = mongoose.model('Budget', budgetSchema);
