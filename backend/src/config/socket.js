const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const registerChatHandlers = require('../sockets/chatSocket');
const logger = require('../utils/logger');

let io = null;

/**
 * Initialize Socket.IO server and bind authorization handlers
 * @param {object} httpServer - Node.js HTTP Server instance
 */
const initSocket = (httpServer) => {
  // Read CORS whitelists matching our HTTP REST configuration
  const allowedOrigins = [
    process.env.CLIENT_URL,
    'http://localhost:8080',
    'http://localhost:5000',
    'http://127.0.0.1:8080',
    'http://127.0.0.1:5000'
  ].filter(Boolean);

  io = new Server(httpServer, {
    cors: {
      // Restrict origins to mitigate Cross-Site WebSocket Hijacking (CSWSH)
      origin: allowedOrigins.length > 0 ? allowedOrigins : '*',
      methods: ['GET', 'POST'],
      credentials: true,
    },
    pingTimeout: 60000, // Close connection after 60s of inactivity
    // Protect against DDoS memory exhaust by capping maximum WebSocket payload sizes (100KB)
    maxHttpBufferSize: 1e5, 
  });

  // JWT Verification Middleware for Socket.IO connections
  io.use(async (socket, next) => {
    try {
      // Check for token in handshake authentication or query params
      const token = 
        socket.handshake.auth?.token || 
        socket.handshake.headers?.authorization?.split(' ')[1] ||
        socket.handshake.query?.token;

      if (!token) {
        return next(new Error('Authentication failed. No token provided.'));
      }

      // Verify token strictly
      const decoded = jwt.verify(token, process.env.JWT_SECRET);

      // Fetch user
      const user = await User.findById(decoded.id).select('-password');
      if (!user) {
        return next(new Error('Authentication failed. User no longer exists.'));
      }

      // Append authenticated user details to socket instance
      socket.user = user;
      next();
    } catch (error) {
      logger.error(`Socket authorization verification failed: ${error.message}`);
      return next(new Error('Authentication failed. Invalid token.'));
    }
  });

  // Handle new authenticated connections
  io.on('connection', async (socket) => {
    logger.info(`Socket client connected: ${socket.id} (User: ${socket.user.name})`);

    try {
      await User.findByIdAndUpdate(socket.user._id, {
        isOnline: true,
      });
      
      // Broadcast user's new online presence state globally
      io.emit('user_status_changed', {
        userId: socket.user._id,
        isOnline: true,
      });
    } catch (err) {
      logger.error(`Error updating online status for user ${socket.user._id}: ${err.message}`);
    }

    // Register modular chat socket event handlers
    registerChatHandlers(io, socket);

    // Global connection state logging and user offline presences updating
    socket.on('disconnect', async () => {
      logger.info(`Socket client disconnected: ${socket.id} (User: ${socket.user.name})`);
      try {
        await User.findByIdAndUpdate(socket.user._id, {
          isOnline: false,
          lastSeen: new Date(),
        });
        
        // Broadcast user's new offline presence state globally
        io.emit('user_status_changed', {
          userId: socket.user._id,
          isOnline: false,
          lastSeen: new Date(),
        });
      } catch (err) {
        logger.error(`Error updating offline status for user ${socket.user._id}: ${err.message}`);
      }
    });
  });

  return io;
};

/**
 * Helper to fetch loaded Socket.IO instance
 */
const getIO = () => {
  if (!io) {
    throw new Error('Socket.IO is not initialized!');
  }
  return io;
};

module.exports = {
  initSocket,
  getIO,
};
