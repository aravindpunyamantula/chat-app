const mongoose = require('mongoose');
const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const User = require('../models/User');

// @desc    Create or retrieve a conversation
// @route   POST /api/chat/conversations
// @access  Private
const createOrGetConversation = async (req, res, next) => {
  try {
    const { participantId, isGroup, groupName, participants } = req.body;
    const currentUserId = req.user._id;

    // Handle Group Conversation creation
    if (isGroup) {
      if (!groupName) {
        return res.status(400).json({
          success: false,
          message: 'Group name is required for group chats.',
        });
      }

      if (!participants || !Array.isArray(participants) || participants.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Group conversations require participants.',
        });
      }

      // Validate that all participants are valid ObjectIds
      const invalidIds = participants.some((pId) => !mongoose.Types.ObjectId.isValid(pId));
      if (invalidIds) {
        return res.status(400).json({
          success: false,
          message: 'One or more participant user IDs are invalid formats.',
        });
      }

      // Add the current user to the group if they aren't already included
      const allParticipants = [...new Set([...participants, currentUserId.toString()])];

      // Validate that all participants actually exist in the database
      const usersCount = await User.countDocuments({ _id: { $in: allParticipants } });
      if (usersCount !== allParticipants.length) {
        return res.status(400).json({
          success: false,
          message: 'One or more participant user IDs do not exist.',
        });
      }

      const conversation = await Conversation.create({
        participants: allParticipants,
        isGroup: true,
        groupName: groupName.trim().substring(0, 100), // Cap group name length to 100 chars
        groupAdmin: currentUserId,
      });

      const populatedConversation = await Conversation.findById(conversation._id)
        .populate('participants', 'name email profileImage isOnline lastSeen')
        .populate('groupAdmin', 'name email profileImage isOnline lastSeen');

      return res.status(201).json({
        success: true,
        conversation: populatedConversation,
      });
    }

    // Handle 1v1 / Direct Message conversation
    if (!participantId) {
      return res.status(400).json({
        success: false,
        message: 'participantId is required for 1v1 conversations.',
      });
    }

    // Validate participantId format
    if (!mongoose.Types.ObjectId.isValid(participantId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid participant recipient ID format.',
      });
    }

    // Prevent direct messaging oneself
    if (participantId.toString() === currentUserId.toString()) {
      return res.status(400).json({
        success: false,
        message: 'You cannot create a conversation with yourself.',
      });
    }

    // Check if participant is a valid user
    const recipient = await User.findById(participantId);
    if (!recipient) {
      return res.status(404).json({
        success: false,
        message: 'Recipient user not found.',
      });
    }

    // Look for existing 1v1 conversation between these exact two participants
    let conversation = await Conversation.findOne({
      isGroup: false,
      participants: { $all: [currentUserId, participantId], $size: 2 },
    });

    if (!conversation) {
      // Create new conversation
      conversation = await Conversation.create({
        participants: [currentUserId, participantId],
        isGroup: false,
      });
    }

    const populatedConversation = await Conversation.findById(conversation._id).populate(
      'participants',
      'name email profileImage isOnline lastSeen'
    );

    res.status(200).json({
      success: true,
      conversation: populatedConversation,
    });
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
      .populate('groupAdmin', 'name email profileImage isOnline lastSeen')
      .populate({
        path: 'lastMessage',
        populate: {
          path: 'sender',
          select: 'name email profileImage isOnline lastSeen',
        },
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

// @desc    Get historical message logs for a conversation
// @route   GET /api/chat/conversations/:id/messages
// @access  Private
const getMessages = async (req, res, next) => {
  try {
    const conversationId = req.params.id;
    const currentUserId = req.user._id;

    // Validate conversationId format
    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid conversation ID format.',
      });
    }

    // Check if conversation exists
    const conversation = await Conversation.findById(conversationId);
    if (!conversation) {
      return res.status(404).json({
        success: false,
        message: 'Conversation not found.',
      });
    }

    // Verify current user is part of the conversation
    const isParticipant = conversation.participants.some(
      (pId) => pId.toString() === currentUserId.toString()
    );
    if (!isParticipant) {
      return res.status(403).json({
        success: false,
        message: 'Access denied. You are not a participant in this conversation.',
      });
    }

    // Parse cursor pagination options
    const limit = parseInt(req.query.limit, 10) || 20;
    const beforeId = req.query.beforeId;

    if (beforeId && !mongoose.Types.ObjectId.isValid(beforeId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid cursor pagination parameter.',
      });
    }

    const query = { conversationId };
    if (beforeId) {
      query._id = { $lt: beforeId };
    }

    const messages = await Message.find(query)
      .populate('sender', 'name email profileImage isOnline lastSeen')
      .sort({ _id: -1 })
      .limit(limit);

    // If we loaded exactly the limit, there are more messages to fetch
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

// @desc    Post/Send a message in a conversation via REST API
// @route   POST /api/chat/conversations/:id/messages
// @access  Private
const sendMessageRest = async (req, res, next) => {
  try {
    const conversationId = req.params.id;
    const currentUserId = req.user._id;
    const { content, messageType, fileUrl } = req.body;

    // (validateMessageBody middleware already verifies content exists, trims and escapes HTML)

    // Validate conversationId format
    if (!mongoose.Types.ObjectId.isValid(conversationId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid conversation ID format.',
      });
    }

    // Check conversation and access
    const conversation = await Conversation.findById(conversationId);
    if (!conversation) {
      return res.status(404).json({
        success: false,
        message: 'Conversation not found.',
      });
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

    // Create message
    const message = await Message.create({
      conversationId,
      sender: currentUserId,
      content,
      messageType: messageType || 'text',
      fileUrl: fileUrl || '',
    });

    // Update conversation's lastMessage reference
    conversation.lastMessage = message._id;
    await conversation.save();

    const populatedMessage = await Message.findById(message._id).populate(
      'sender',
      'name email profileImage isOnline lastSeen'
    );

    res.status(201).json({
      success: true,
      message: populatedMessage,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createOrGetConversation,
  getConversations,
  getMessages,
  sendMessageRest,
};
