const express = require('express');
const router = express.Router();
const {
  createOrGetConversation,
  getConversations,
  getMessages,
  sendMessageRest,
  uploadMedia,
} = require('../controllers/chatController');
const { protect } = require('../middlewares/authMiddleware');
const { validateMessageBody } = require('../middlewares/chatValidationMiddleware');
const { upload, enforceSizeLimit } = require('../middlewares/uploadMiddleware');

// All chat routes are protected with JWT
router.use(protect);

router.route('/conversations')
  .post(createOrGetConversation)
  .get(getConversations);

router.route('/conversations/:id/messages')
  .get(getMessages)
  .post(validateMessageBody, sendMessageRest);

// Media upload: single file, field name 'file'
router.post('/upload', upload.single('file'), enforceSizeLimit, uploadMedia);

module.exports = router;
