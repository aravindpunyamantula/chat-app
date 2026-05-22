const winston = require('winston');

// Determine log level (default: 'info' in prod, 'debug' in dev)
const level = process.env.LOG_LEVEL || (process.env.NODE_ENV === 'development' ? 'debug' : 'info');

// Custom format combining levels, timestamps, and error tracing metadata
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }), // Include stack trace on errors
  winston.format.splat(),
  winston.format.json() // Production structure: pure JSON lines
);

// Formatted console print layout specifically for local developer readability
const devConsoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.printf(({ timestamp, level, message, stack, ...meta }) => {
    const metaString = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : '';
    if (stack) {
      return `[${timestamp}] ${level}: ${message}\nStack: ${stack}`;
    }
    return `[${timestamp}] ${level}: ${message}${metaString}`;
  })
);

// Instantiate global Winston logger instance
const logger = winston.createLogger({
  level,
  format: logFormat,
  transports: [
    new winston.transports.Console({
      format: process.env.NODE_ENV === 'production' ? logFormat : devConsoleFormat,
      stderrLevels: ['error'], // Send error logs strictly to stderr
    }),
  ],
});

module.exports = logger;
