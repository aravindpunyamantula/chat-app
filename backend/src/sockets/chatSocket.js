const mongoose = require('mongoose');
const Conversation = require('../models/Conversation');
const Message = require('../models/Message');
const { escapeHTML } = require('../middlewares/chatValidationMiddleware');
const logger = require('../utils/logger');

/**
 * Register Chat event handlers on the current Socket client
 * @param {object} io - Global Socket.IO Server instance
 * @param {object} socket - Socket instance representing single connection
 */
const registerChatHandlers = (io, socket) => {
  
  // 1. Client joins a conversation room (Secured against BOLA/IDOR room leaks!)
  socket.on('join_conversation', async (conversationId) => {
    try {
      if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) {
        return socket.emit('error_response', { message: 'Invalid room format.' });
      }
      
      // Load conversation details
      const conversation = await Conversation.findById(conversationId);
      if (!conversation) {
        return socket.emit('error_response', { message: 'Conversation not found.' });
      }

      // Verify that the connected user is actually a participant of this conversation
      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) {
        logger.warn(`[SECURITY WARN] User [${socket.user.name}] attempted unauthorized join on room: ${conversationId}`);
        return socket.emit('error_response', {
          message: 'Access denied. You are not a participant in this conversation.',
        });
      }
      
      socket.join(conversationId);
      logger.info(`User [${socket.user.name}] joined conversation room: ${conversationId}`);
      
      // Notify other users that someone came online in this thread
      socket.to(conversationId).emit('user_online_status', {
        userId: socket.user._id,
        name: socket.user.name,
        status: 'online',
      });
    } catch (err) {
      logger.error(`Socket join_conversation error: ${err.message}`);
      socket.emit('error_response', { message: 'Failed to join conversation room.' });
    }
  });

  // 2. Client leaves a conversation room
  socket.on('leave_conversation', (conversationId) => {
    if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) return;
    
    socket.leave(conversationId);
    logger.info(`User [${socket.user.name}] left conversation room: ${conversationId}`);
  });

  // 3. Client sends a real-time message (Secured with size caps, HTML XSS escaping, and BOLA checks!)
  socket.on('send_message', async (data, ack) => {
    try {
      const { conversationId, content, messageType, fileUrl, tempId } = data;

      // Validate conversation format
      if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) {
        return socket.emit('error_response', { message: 'Invalid conversation format.' });
      }

      // Validate message presence & length boundaries
      if (content === undefined || typeof content !== 'string') {
        return socket.emit('error_response', { message: 'Content is required and must be a string.' });
      }

      const trimmedContent = content.trim();
      const isMediaType = ['image', 'video', 'file'].includes(messageType);

      // Text messages must have content; media messages may have empty content (caption is optional)
      if (!isMediaType && trimmedContent.length === 0) {
        return socket.emit('error_response', { message: 'Message content cannot be empty.' });
      }

      if (trimmedContent.length > 5000) {
        return socket.emit('error_response', { message: 'Message exceeds the 5,000 characters limit.' });
      }

      // Check if conversation exists and user is a participant
      const conversation = await Conversation.findById(conversationId);
      if (!conversation) {
        return socket.emit('error_response', { message: 'Conversation not found.' });
      }

      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) {
        logger.warn(`[SECURITY WARN] User [${socket.user.name}] attempted unauthorized send on room: ${conversationId}`);
        return socket.emit('error_response', {
          message: 'Unauthorized. You are not a participant in this conversation.',
        });
      }

      // Escape HTML characters to neutralize Stored persistent XSS vectors
      const sanitizedContent = escapeHTML(trimmedContent);

      const allowedTypes = ['text', 'image', 'video', 'file'];
      const safeType = allowedTypes.includes(messageType) ? messageType : 'text';

      // Create message document in database
      const message = await Message.create({
        conversationId,
        sender: socket.user._id,
        content: sanitizedContent,
        messageType: safeType,
        fileUrl: fileUrl || '',
        status: 'sent',
      });

      // Update parent conversation lastMessage indicator
      conversation.lastMessage = message._id;
      await conversation.save();

      // Retrieve fully populated message object
      const populatedMessage = await Message.findById(message._id).populate(
        'sender',
        'name email profileImage isOnline lastSeen'
      );

      // Broadcast to all participants in the conversation room
      io.to(conversationId).emit('new_message', populatedMessage);
      
      // Return server-side write acknowledgement to trigger client tempId swapping
      if (typeof ack === 'function') {
        ack({
          success: true,
          tempId: tempId || null,
          message: populatedMessage,
          status: 'sent',
        });
      }
      
      logger.info(`Msg from [${socket.user.name}] broadcasted in room: ${conversationId}`);
    } catch (error) {
      logger.error(`Socket send_message error: ${error.message}`);
      socket.emit('error_response', {
        message: 'Failed to process and send message.',
      });
    }
  });

  // 4. Micro-interactions: User typing status broadcaster (Secured against BOLA/IDOR leaks!)
  socket.on('typing', async (data) => {
    try {
      const { conversationId, isTyping } = data;
      if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) return;

      const conversation = await Conversation.findById(conversationId);
      if (!conversation) return;

      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) return;

      // Broadcast to everyone else in the conversation room
      socket.to(conversationId).emit('user_typing', {
        userId: socket.user._id,
        name: socket.user.name,
        isTyping: !!isTyping,
      });
    } catch (err) {
      logger.error(`Socket typing error: ${err.message}`);
    }
  });

  // 5. Recipient client acknowledges receipt (delivered status) (Secured against BOLA/IDOR status tampering!)
  socket.on('message_delivered', async (data) => {
    try {
      const { messageId } = data;
      if (!messageId || !mongoose.Types.ObjectId.isValid(messageId)) return;

      const message = await Message.findById(messageId);
      if (!message) return;

      // Validate recipient belongs to the message's conversation thread
      const conversation = await Conversation.findById(message.conversationId);
      if (!conversation) return;

      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) return;

      // Only transition to delivered if current state is 'sent'
      if (message.status === 'sent') {
        message.status = 'delivered';
        await message.save();

        // Broadcast status update event to conversation room
        io.to(message.conversationId.toString()).emit('message_status_changed', {
          messageId: message._id,
          conversationId: message.conversationId,
          status: 'delivered',
        });
        logger.info(`Message ${messageId} marked as delivered.`);
      }
    } catch (err) {
      logger.error(`Socket message_delivered error: ${err.message}`);
    }
  });

  // 6. Recipient opens chat room (read status) (Secured against BOLA/IDOR status tampering!)
  socket.on('message_read', async (data) => {
    try {
      const { conversationId } = data;
      if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) return;

      // Validate user is a participant of this conversation
      const conversation = await Conversation.findById(conversationId);
      if (!conversation) return;

      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) return;

      // Mark all messages from other senders inside the conversation as read
      const result = await Message.updateMany(
        {
          conversationId,
          sender: { $ne: socket.user._id },
          status: { $ne: 'read' },
        },
        { status: 'read' }
      );

      if (result.modifiedCount > 0) {
        // Broadcast read receipts event globally to conversation room
        io.to(conversationId).emit('messages_read_receipt', {
          conversationId,
          readerId: socket.user._id,
          status: 'read',
        });
        logger.info(`Messages in room ${conversationId} marked as read by ${socket.user.name}.`);
      }
    } catch (err) {
      logger.error(`Socket message_read error: ${err.message}`);
    }
  });


  // ─── Watch Together ──────────────────────────────────────────────────────────

  // 7. Host starts a watch session and shares a video URL with partner
  socket.on('watch_session_start', async (data) => {
    try {
      const { conversationId, videoUrl } = data;
      if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) return;
      if (!videoUrl || typeof videoUrl !== 'string') return;

      const conversation = await Conversation.findById(conversationId);
      if (!conversation) return;

      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) return;

      // Relay session start to partner only (not back to sender)
      socket.to(conversationId).emit('watch_session_started', {
        hostId: socket.user._id,
        hostName: socket.user.name,
        videoUrl,
      });

      logger.info(`Watch session started by [${socket.user.name}] in room: ${conversationId}`);
    } catch (err) {
      logger.error(`Socket watch_session_start error: ${err.message}`);
    }
  });

  // 8. Viewer notifies host they've joined the session
  socket.on('watch_session_join', async (data) => {
    try {
      const { conversationId } = data;
      if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) return;

      const conversation = await Conversation.findById(conversationId);
      if (!conversation) return;

      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) return;

      socket.to(conversationId).emit('watch_session_viewer_joined', {
        viewerId: socket.user._id,
        viewerName: socket.user.name,
      });
    } catch (err) {
      logger.error(`Socket watch_session_join error: ${err.message}`);
    }
  });

  // 9. Host sends play/pause/seek sync to partner
  socket.on('watch_sync', async (data) => {
    try {
      const { conversationId, action, position } = data;
      if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) return;

      const validActions = ['play', 'pause', 'seek'];
      if (!validActions.includes(action)) return;

      const conversation = await Conversation.findById(conversationId);
      if (!conversation) return;

      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) return;

      socket.to(conversationId).emit('watch_sync', {
        action,
        position: typeof position === 'number' ? position : 0,
        fromId: socket.user._id,
      });
    } catch (err) {
      logger.error(`Socket watch_sync error: ${err.message}`);
    }
  });

  // 10. Either user ends the watch session
  socket.on('watch_session_end', async (data) => {
    try {
      const { conversationId } = data;
      if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) return;

      const conversation = await Conversation.findById(conversationId);
      if (!conversation) return;

      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) return;

      socket.to(conversationId).emit('watch_session_ended', {
        byId: socket.user._id,
        byName: socket.user.name,
      });

      logger.info(`Watch session ended by [${socket.user.name}] in room: ${conversationId}`);
    } catch (err) {
      logger.error(`Socket watch_session_end error: ${err.message}`);
    }
  });

  // ─── WebRTC Signaling (for future P2P video streaming) ───────────────────────

  // 11. Relay WebRTC offer (SDP) from caller to partner
  socket.on('webrtc_offer', async (data) => {
    try {
      const { conversationId, sdp } = data;
      if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) return;
      if (!sdp) return;

      const conversation = await Conversation.findById(conversationId);
      if (!conversation) return;

      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) return;

      socket.to(conversationId).emit('webrtc_offer', {
        sdp,
        fromId: socket.user._id,
      });
    } catch (err) {
      logger.error(`Socket webrtc_offer error: ${err.message}`);
    }
  });

  // 12. Relay WebRTC answer (SDP) from callee back to caller
  socket.on('webrtc_answer', async (data) => {
    try {
      const { conversationId, sdp } = data;
      if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) return;
      if (!sdp) return;

      const conversation = await Conversation.findById(conversationId);
      if (!conversation) return;

      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) return;

      socket.to(conversationId).emit('webrtc_answer', {
        sdp,
        fromId: socket.user._id,
      });
    } catch (err) {
      logger.error(`Socket webrtc_answer error: ${err.message}`);
    }
  });

  // 13. Relay ICE candidates between peers
  socket.on('webrtc_ice_candidate', async (data) => {
    try {
      const { conversationId, candidate } = data;
      if (!conversationId || !mongoose.Types.ObjectId.isValid(conversationId)) return;
      if (!candidate) return;

      const conversation = await Conversation.findById(conversationId);
      if (!conversation) return;

      const isParticipant = conversation.participants.some(
        (pId) => pId.toString() === socket.user._id.toString()
      );
      if (!isParticipant) return;

      socket.to(conversationId).emit('webrtc_ice_candidate', {
        candidate,
        fromId: socket.user._id,
      });
    } catch (err) {
      logger.error(`Socket webrtc_ice_candidate error: ${err.message}`);
    }
  });

};

module.exports = registerChatHandlers;
