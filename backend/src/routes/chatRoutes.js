const express = require('express');
const router = express.Router();
const {
  createOrGetConversation,
  getConversations,
  getMessages,
  sendMessageRest,
} = require('../controllers/chatController');
const { protect } = require('../middlewares/authMiddleware');
const { validateMessageBody } = require('../middlewares/chatValidationMiddleware');

// All chat routes are protected with JWT
router.use(protect);

router.route('/conversations')
  .post(createOrGetConversation)
  .get(getConversations);

router.route('/conversations/:id/messages')
  .get(getMessages)
  .post(validateMessageBody, sendMessageRest);

module.exports = router;
