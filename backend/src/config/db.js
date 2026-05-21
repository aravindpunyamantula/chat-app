const mongoose = require('mongoose');
const logger = require('../utils/logger');

const connectDB = async () => {
  try {
    const connStr = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/chat-app-db';
    
    // Configure event listeners before initiating connection
    mongoose.connection.on('connected', () => {
      logger.info('MongoDB successfully connected to database server.');
    });

    mongoose.connection.on('error', (err) => {
      logger.error(`MongoDB connection error state triggered: ${err.message}`);
    });

    mongoose.connection.on('disconnected', () => {
      logger.warn('MongoDB reference disconnected.');
    });

    // Establish connection
    const conn = await mongoose.connect(connStr);
    logger.info(`MongoDB Connected: ${conn.connection.host}/${conn.connection.name}`);
  } catch (error) {
    logger.error(`MongoDB connection initiation failure: ${error.message}`);
    process.exit(1);
  }
};

module.exports = connectDB;
