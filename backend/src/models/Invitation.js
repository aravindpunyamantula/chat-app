const mongoose = require('mongoose');
const crypto = require('crypto');

const invitationSchema = new mongoose.Schema(
  {
    inviterId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    code: {
      type: String,
      required: true,
      unique: true,
      uppercase: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'expired'],
      default: 'pending',
      index: true,
    },
    inviteeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    conversationId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Conversation',
      default: null,
    },
    expiresAt: {
      type: Date,
      required: true,
    },
  },
  { timestamps: true }
);

// MongoDB TTL index — purges expired documents automatically
invitationSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const generateCode = () => {
  // 6-char hex (e.g. A3F72C) — 16^6 = 16M combinations, low collision risk
  return crypto.randomBytes(3).toString('hex').toUpperCase();
};

invitationSchema.statics.generateCode = generateCode;

const Invitation = mongoose.model('Invitation', invitationSchema);
module.exports = { Invitation, generateCode };
