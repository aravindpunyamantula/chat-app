// Load environment configurations
require('dotenv').config();

const http = require('http');
const mongoose = require('mongoose');
const app = require('./src/app');
const connectDB = require('./src/config/db');
const { initSocket } = require('./src/config/socket');
const logger = require('./src/utils/logger');

// PORT Configuration
const PORT = process.env.PORT || 5000;

// Connect to MongoDB
connectDB();

// Build Native Node HTTP Server around Express App
const server = http.createServer(app);

// Integrate Socket.IO server engine
initSocket(server);

// Boot up Node Server
const serverInstance = server.listen(PORT, () => {
  logger.info(`===================================================`);
  logger.info(` Real-Time Chat Server Bootstrapped Successfully.`);
  logger.info(` Running in [${process.env.NODE_ENV || 'development'}] mode`);
  logger.info(` API Endpoint: http://localhost:${PORT}`);
  logger.info(` WebSocket:    ws://localhost:${PORT}`);
  logger.info(`===================================================`);
});

// Graceful Shutdown Protocol
const gracefulShutdown = (signal) => {
  logger.warn(`Received ${signal}. Starting graceful shutdown protocol...`);

  // 1. Stop taking in new requests and close connection socket servers
  serverInstance.close(async () => {
    logger.info('HTTP and WebSocket servers shut down.');

    try {
      // 2. Safely close database connection pool
      await mongoose.connection.close();
      logger.info('MongoDB connection pool drained and closed.');
      
      logger.info('Graceful shutdown completed successfully. Bye!');
      process.exit(0);
    } catch (err) {
      logger.error('Error during MongoDB connection shutdown:', { error: err.message });
      process.exit(1);
    }
  });

  // Force close after 10s if connections remain stuck
  setTimeout(() => {
    logger.error('Forced shutdown: Active connections could not be closed in time.');
    process.exit(1);
  }, 10000);
};

// Listen for termination signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Capture uncaught exceptions to prevent silent crashes
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception occurred:', error);
  // Perform emergency graceful exit
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Promise Rejection at:', { promise, reason });
});
