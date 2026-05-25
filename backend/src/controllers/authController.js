const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const User = require('../models/User');
const RefreshToken = require('../models/RefreshToken');
const logger = require('../utils/logger');

// Ensure JWT secret is present
if (!process.env.JWT_SECRET) {
  logger.error('FATAL ERROR: JWT_SECRET environment variable is missing.');
  process.exit(1);
}

/**
 * Generate a short-lived Access Token
 * @param {string} id - The MongoDB user ID
 */
const generateAccessToken = (id) => {
  return jwt.sign(
    { id },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
    }
  );
};

/**
 * Generate a long-lived opaque Refresh Token and save in DB
 * @param {string} userId - The MongoDB user ID
 */
const generateRefreshToken = async (userId) => {
  const tokenString = crypto.randomBytes(40).toString('hex');
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

  await RefreshToken.create({
    userId,
    token: tokenString,
    expiresAt,
  });

  return tokenString;
};

// @desc    Register a new user
// @route   POST /api/auth/register
// @access  Public
const registerUser = async (req, res, next) => {
  try {
    const { name, email, password, profileImage } = req.body;

    // Validate inputs
    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide a name, email, and password.',
      });
    }

    // Check if user already exists
    const emailExists = await User.findOne({ email });
    if (emailExists) {
      return res.status(400).json({
        success: false,
        message: 'A user with this email address already exists.',
      });
    }

    // Create user
    const user = await User.create({
      name,
      email,
      password,
      profileImage: profileImage || '',
      isOnline: true,
      lastSeen: new Date(),
    });

    // Generate Access & Refresh tokens
    const accessToken = generateAccessToken(user._id);
    const refreshToken = await generateRefreshToken(user._id);

    res.status(201).json({
      success: true,
      accessToken,
      refreshToken,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        profileImage: user.profileImage,
        isOnline: user.isOnline,
        lastSeen: user.lastSeen,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Authenticate user & get tokens
// @route   POST /api/auth/login
// @access  Public
const loginUser = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    // Validate inputs
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide an email and password.',
      });
    }

    // Find user (explicitly selecting password to check credentials)
    const user = await User.findOne({ email }).select('+password');
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    // Check if password matches
    const isMatch = await user.matchPassword(password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    // Set online status to true on login
    user.isOnline = true;
    user.lastSeen = new Date();
    await user.save();

    // Generate Access & Refresh tokens
    const accessToken = generateAccessToken(user._id);
    const refreshToken = await generateRefreshToken(user._id);

    res.status(200).json({
      success: true,
      accessToken,
      refreshToken,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        profileImage: user.profileImage,
        isOnline: user.isOnline,
        lastSeen: user.lastSeen,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Refresh Access Token using rotation
// @route   POST /api/auth/refresh
// @access  Public
const refreshAccessToken = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        message: 'Refresh token is required.',
      });
    }

    // Find token in database
    const tokenDoc = await RefreshToken.findOne({ token: refreshToken });

    if (!tokenDoc) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or revoked refresh token.',
      });
    }

    // BREACH DETECTION: If token is already marked as replaced, someone is attempting reuse!
    if (tokenDoc.replacedByToken) {
      logger.warn(`[SECURITY BREACH DETECTED] Refresh token reuse attempted for userId: ${tokenDoc.userId}. Revoking all user active sessions immediately.`);
      // Delete all refresh tokens for this user
      await RefreshToken.deleteMany({ userId: tokenDoc.userId });
      
      // Update online status to offline
      await User.findByIdAndUpdate(tokenDoc.userId, { isOnline: false });

      return res.status(403).json({
        success: false,
        message: 'Security breach detected. All sessions revoked. Please re-authenticate.',
      });
    }

    // Check expiry
    if (tokenDoc.isExpired()) {
      await RefreshToken.deleteOne({ _id: tokenDoc._id });
      return res.status(401).json({
        success: false,
        message: 'Refresh token has expired. Please log in again.',
      });
    }

    // Generate new Access and Refresh tokens (Rotation!)
    const newAccessToken = generateAccessToken(tokenDoc.userId);
    const newRefreshTokenString = crypto.randomBytes(40).toString('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    // Mark current token as replaced
    tokenDoc.replacedByToken = newRefreshTokenString;
    await tokenDoc.save();

    // Create the new rotated Refresh Token
    await RefreshToken.create({
      userId: tokenDoc.userId,
      token: newRefreshTokenString,
      expiresAt,
    });

    res.status(200).json({
      success: true,
      accessToken: newAccessToken,
      refreshToken: newRefreshTokenString,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Secure Logout & Session Revocation
// @route   POST /api/auth/logout
// @access  Public (or authenticated)
const logoutUser = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      // Find the token to identify user
      const tokenDoc = await RefreshToken.findOne({ token: refreshToken });
      if (tokenDoc) {
        // Set offline status
        await User.findByIdAndUpdate(tokenDoc.userId, {
          isOnline: false,
          lastSeen: new Date(),
        });
        
        // Remove token from database to invalidate session
        await RefreshToken.deleteOne({ _id: tokenDoc._id });
      }
    }

    res.status(200).json({
      success: true,
      message: 'Logged out successfully. Session revoked.',
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get current user profile
// @route   GET /api/auth/profile
// @access  Private
const getProfile = async (req, res, next) => {
  try {
    res.status(200).json({
      success: true,
      user: req.user,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get all users except the logged-in user
// @route   GET /api/auth/users
// @access  Private
const getUsersExceptMe = async (req, res, next) => {
  try {
    const currentUserId = req.user._id;
    const { search, limit = 50, page = 1 } = req.query;
    
    // Calculate skip boundary for page scrolling
    const skip = (parseInt(page, 10) - 1) * parseInt(limit, 10);

    const query = { _id: { $ne: currentUserId } };

    // If query includes search term, filter users by case-insensitive name regex match
    if (search && search.trim().length > 0) {
      query.name = { $regex: search.trim(), $options: 'i' };
    }

    const users = await User.find(query)
      .select('name email profileImage isOnline lastSeen')
      .sort({ name: 1 })
      .skip(skip)
      .limit(parseInt(limit, 10));

    res.status(200).json({
      success: true,
      count: users.length,
      page: parseInt(page, 10),
      users,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  registerUser,
  loginUser,
  refreshAccessToken,
  logoutUser,
  getProfile,
  getUsersExceptMe,
};
