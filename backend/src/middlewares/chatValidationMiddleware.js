const mongoose = require('mongoose');

/**
 * Escapes HTML characters to prevent XSS injections
 * @param {string} str - User input string
 */
const escapeHTML = (str) => {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;');
};

/**
 * Middleware to strictly validate message posting body and parameter parameters
 */
const validateMessageBody = (req, res, next) => {
  const { content } = req.body;
  const conversationId = req.params.id;

  // 1. Verify Conversation ID format is a valid MongoDB ObjectId
  if (conversationId && !mongoose.Types.ObjectId.isValid(conversationId)) {
    return res.status(400).json({
      success: false,
      message: 'Invalid conversation format. Please provide a valid 24-character hexadecimal ID.',
    });
  }

  // 2. Verify message content is present and is a string
  if (content === undefined || typeof content !== 'string') {
    return res.status(400).json({
      success: false,
      message: 'Message content is required and must be a string.',
    });
  }

  const trimmedContent = content.trim();

  // 3. Verify message content size boundaries (1 - 5,000 characters after trimming)
  if (trimmedContent.length === 0) {
    return res.status(400).json({
      success: false,
      message: 'Message content cannot be empty or whitespace-only.',
    });
  }

  if (trimmedContent.length > 5000) {
    return res.status(400).json({
      success: false,
      message: 'Message content length exceeds the 5,000 characters limit. Payload rejected.',
    });
  }

  // 4. Escape dangerous HTML characters to neutralizepersistent Stored XSS scripts
  req.body.content = escapeHTML(trimmedContent);
  next();
};

module.exports = {
  validateMessageBody,
  escapeHTML,
};
