const express = require('express');
const router = express.Router();
const { getInviteStatus, acceptInvite, refreshCode } = require('../controllers/inviteController');
const { protect } = require('../middlewares/authMiddleware');

router.use(protect);

router.get('/status', getInviteStatus);
router.post('/accept', acceptInvite);
router.post('/refresh-code', refreshCode);

module.exports = router;
