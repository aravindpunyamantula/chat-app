const path = require('path');
const mongoose = require('mongoose');
const Conversation = require('../models/Conversation');
const Message = require('../models/Message');

// @desc    Get the bonded conversation for the current user (read-only — creation is via /api/invite/accept)
// @route   POST /api/chat/conversations  (kept for sync-manager compatibility, now read-only)
// @access  Private
const createOrGetConversation = async (req, res, next) => {
  try {
    const currentUserId = req.user._id;

    // Only return the existing bonded conversation — new ones are created through the invite flow
    const conversation = await Conversation.findOne({
      participants: currentUserId,
      isBonded: true,
    })
      .populate('participants', 'name email profileImage isOnline lastSeen');

    if (!conversation) {
      return res.status(404).json({
        success: false,
        message: 'No bonded conversation found. Please accept an invite first.',
      });
    }

    res.status(200).json({ success: true, conversation });
  } catch (error) {
    next(error);
  }
};

// @desc    Get all conversations for the current user
// @route   GET /api/chat/conversations
// @access  Private
const getConversations = async (req, res, next) => {
  try {
    const currentUserId = req.user._id;

    const conversations = await Conversation.find({
      participants: currentUserId,
    })
      .populate('participants', 'name email profileImage isOnline lastSeen')
      .populate({
        path: 'lastMessage',
        populate: { path: 'sender', select: 'name email profileImage isOnline lastSeen' },
      })
      .sort({ updatedAt: -1 });

    res.status(200).json({
      success: true,
      count: conversations.length,
      conversations,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get historical messages for a conversation
// @route   GET /api/chat/conversations/:id/messages
// @access  Private
const getMessages = async (req, res, next) => {
  try {
    const conversationId = req.params.id;
    const currentUserId = req.user._id;

    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
      return res.status(400).json({ success: false, message: 'Invalid conversation ID format.' });
    }

    const conversation = await Conversation.findById(conversationId);
    if (!conversation) {
      return res.status(404).json({ success: false, message: 'Conversation not found.' });
    }

    const isParticipant = conversation.participants.some(
      (pId) => pId.toString() === currentUserId.toString()
    );
    if (!isParticipant) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You are not a participant in this conversation.',
      });
    }

    const limit = parseInt(req.query.limit, 10) || 20;
    const beforeId = req.query.beforeId;

    if (beforeId && !mongoose.Types.ObjectId.isValid(beforeId)) {
      return res.status(400).json({ success: false, message: 'Invalid cursor pagination parameter.' });
    }

    const query = { conversationId };
    if (beforeId) query._id = { $lt: beforeId };

    const messages = await Message.find(query)
      .populate('sender', 'name email profileImage isOnline lastSeen')
      .sort({ _id: -1 })
      .limit(limit);

    const hasMore = messages.length === limit;

    res.status(200).json({
      success: true,
      count: messages.length,
      hasMore,
      messages: messages.reverse(),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Send a message via REST (offline queue fallback)
// @route   POST /api/chat/conversations/:id/messages
// @access  Private
const sendMessageRest = async (req, res, next) => {
  try {
    const conversationId = req.params.id;
    const currentUserId = req.user._id;
    const { content, messageType, fileUrl } = req.body;

    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
      return res.status(400).json({ success: false, message: 'Invalid conversation ID format.' });
    }

    const conversation = await Conversation.findById(conversationId);
    if (!conversation) {
      return res.status(404).json({ success: false, message: 'Conversation not found.' });
    }

    const isParticipant = conversation.participants.some(
      (pId) => pId.toString() === currentUserId.toString()
    );
    if (!isParticipant) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You are not a participant in this conversation.',
      });
    }

    const message = await Message.create({
      conversationId,
      sender: currentUserId,
      content,
      messageType: messageType || 'text',
      fileUrl: fileUrl || '',
    });

    conversation.lastMessage = message._id;
    await conversation.save();

    const populated = await Message.findById(message._id).populate(
      'sender',
      'name email profileImage isOnline lastSeen'
    );

    res.status(201).json({ success: true, message: populated });
  } catch (error) {
    next(error);
  }
};

// @desc    Upload image or video, return the served URL
// @route   POST /api/chat/upload
// @access  Private
const uploadMedia = (req, res) => {
  // req.file is guaranteed by enforceSizeLimit middleware
  const filename = req.file.filename;
  const isVideo = req.file.mimetype.startsWith('video/');

  const baseUrl = process.env.SERVER_URL || `http://localhost:${process.env.PORT || 5000}`;
  const fileUrl = `${baseUrl}/uploads/${filename}`;

  return res.status(201).json({
    success: true,
    fileUrl,
    messageType: isVideo ? 'video' : 'image',
    originalName: path.basename(req.file.originalname),
    size: req.file.size,
  });
};

module.exports = {
  createOrGetConversation,
  getConversations,
  getMessages,
  sendMessageRest,
  uploadMedia,
};
