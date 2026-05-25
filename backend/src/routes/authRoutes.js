const express = require('express');
const router = express.Router();
const {
  registerUser,
  loginUser,
  refreshAccessToken,
  logoutUser,
  getProfile,
  getUsersExceptMe,
} = require('../controllers/authController');
const { protect } = require('../middlewares/authMiddleware');

router.post('/register', registerUser);
router.post('/login', loginUser);
router.post('/refresh', refreshAccessToken);
router.post('/logout', logoutUser);
router.get('/profile', protect, getProfile);
router.get('/users', protect, getUsersExceptMe);

module.exports = router;
