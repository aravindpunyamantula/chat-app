const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Ensure JWT secret is present at middleware load time
if (!process.env.JWT_SECRET) {
  console.error('FATAL ERROR: JWT_SECRET environment variable is missing.');
  process.exit(1);
}

const protect = async (req, res, next) => {
  let token;

  // Extract token from Bearer authorization header
  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer')
  ) {
    try {
      // Get token from header: "Bearer <token>"
      token = req.headers.authorization.split(' ')[1];

      // Verify access token (strict signature check without fallback keys)
      const decoded = jwt.verify(token, process.env.JWT_SECRET);

      // Get user from the database, exclude password field
      req.user = await User.findById(decoded.id).select('-password');
      
      if (!req.user) {
        return res.status(401).json({
          success: false,
          message: 'User belonging to this token no longer exists.',
        });
      }

      return next();
    } catch (error) {
      // Return structured 401 code for token errors to trigger frontend dynamic refreshes
      let msg = 'Not authorized. Token verification failed.';
      if (error.name === 'TokenExpiredError') {
        msg = 'Access token has expired.';
      } else if (error.name === 'JsonWebTokenError') {
        msg = 'Invalid token signature.';
      }
      
      return res.status(401).json({
        success: false,
        message: msg,
      });
    }
  }

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Not authorized to access this route. No token provided.',
    });
  }
};

module.exports = { protect };
