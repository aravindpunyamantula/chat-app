const { Invitation, generateCode } = require('../models/Invitation');
const Conversation = require('../models/Conversation');
const logger = require('../utils/logger');

// Returns the bonded conversation for userId, or null
const findBondedConversation = (userId) =>
  Conversation.findOne({ participants: userId, isBonded: true });

// Returns the user's active pending invite, or null
const findMyPendingInvite = (userId) =>
  Invitation.findOne({
    inviterId: userId,
    status: 'pending',
    expiresAt: { $gt: new Date() },
  });

// @desc    Get bond status (are we bonded? what's our invite code?)
// @route   GET /api/invite/status
// @access  Private
const getInviteStatus = async (req, res, next) => {
  try {
    const userId = req.user._id;

    const bondedConvo = await findBondedConversation(userId);

    if (bondedConvo) {
      const populated = await bondedConvo.populate(
        'participants',
        'name email profileImage isOnline lastSeen'
      );
      const partner = populated.participants.find(
        (p) => p._id.toString() !== userId.toString()
      );

      return res.json({
        success: true,
        bonded: true,
        conversationId: populated._id,
        partner,
        myCode: null,
      });
    }

    // Not bonded — ensure user has a live pending invite code
    let invite = await findMyPendingInvite(userId);

    if (!invite) {
      let code;
      for (let i = 0; i < 10; i++) {
        code = generateCode();
        const clash = await Invitation.findOne({ code, status: 'pending' });
        if (!clash) break;
      }
      invite = await Invitation.create({
        inviterId: userId,
        code,
        status: 'pending',
        expiresAt: new Date(Date.now() + 72 * 60 * 60 * 1000), // 72 h
      });
    }

    res.json({
      success: true,
      bonded: false,
      conversationId: null,
      partner: null,
      myCode: invite.code,
      expiresAt: invite.expiresAt,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Accept a partner's invite code and form a bond
// @route   POST /api/invite/accept
// @access  Private
const acceptInvite = async (req, res, next) => {
  try {
    const { code } = req.body;
    const currentUserId = req.user._id;

    if (!code || typeof code !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'Invite code is required.',
      });
    }

    const normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.length !== 6 || !/^[A-F0-9]{6}$/.test(normalizedCode)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid code format. Must be a 6-character hex code.',
      });
    }

    // Block if current user is already bonded
    const myBond = await findBondedConversation(currentUserId);
    if (myBond) {
      return res.status(400).json({
        success: false,
        message: 'You are already bonded with someone.',
      });
    }

    const invite = await Invitation.findOne({
      code: normalizedCode,
      status: 'pending',
      expiresAt: { $gt: new Date() },
    });

    if (!invite) {
      return res.status(404).json({
        success: false,
        message: 'Invalid or expired invite code.',
      });
    }

    if (invite.inviterId.toString() === currentUserId.toString()) {
      return res.status(400).json({
        success: false,
        message: 'You cannot accept your own invite code.',
      });
    }

    // Block if the inviter is already bonded with someone else
    const inviterBond = await findBondedConversation(invite.inviterId);
    if (inviterBond) {
      return res.status(400).json({
        success: false,
        message: 'This invite is no longer valid.',
      });
    }

    // Create the one-and-only bonded conversation
    const conversation = await Conversation.create({
      participants: [invite.inviterId, currentUserId],
      isGroup: false,
      isBonded: true,
    });

    // Finalize invitation record
    invite.status = 'accepted';
    invite.inviteeId = currentUserId;
    invite.conversationId = conversation._id;
    await invite.save();

    // Expire all remaining pending invites from both users
    await Invitation.updateMany(
      {
        inviterId: { $in: [invite.inviterId, currentUserId] },
        status: 'pending',
        _id: { $ne: invite._id },
      },
      { status: 'expired' }
    );

    const populated = await Conversation.findById(conversation._id).populate(
      'participants',
      'name email profileImage isOnline lastSeen'
    );

    const partner = populated.participants.find(
      (p) => p._id.toString() !== currentUserId.toString()
    );

    logger.info(`Bond formed: ${invite.inviterId} <-> ${currentUserId}`);

    res.status(201).json({
      success: true,
      message: 'Bonded successfully.',
      conversation: populated,
      partner,
    });
  } catch (err) {
    next(err);
  }
};

// @desc    Regenerate invite code (invalidates previous one)
// @route   POST /api/invite/refresh-code
// @access  Private
const refreshCode = async (req, res, next) => {
  try {
    const userId = req.user._id;

    const bonded = await findBondedConversation(userId);
    if (bonded) {
      return res.status(400).json({
        success: false,
        message: 'Already bonded — cannot generate a new code.',
      });
    }

    // Expire all existing pending codes for this user
    await Invitation.updateMany(
      { inviterId: userId, status: 'pending' },
      { status: 'expired' }
    );

    let code;
    for (let i = 0; i < 10; i++) {
      code = generateCode();
      const clash = await Invitation.findOne({ code, status: 'pending' });
      if (!clash) break;
    }

    const invite = await Invitation.create({
      inviterId: userId,
      code,
      status: 'pending',
      expiresAt: new Date(Date.now() + 72 * 60 * 60 * 1000),
    });

    res.json({
      success: true,
      myCode: invite.code,
      expiresAt: invite.expiresAt,
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { getInviteStatus, acceptInvite, refreshCode };
