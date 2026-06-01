const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const apiRouter = require('./routes');
const errorHandler = require('./middlewares/errorMiddleware');

// Initialize Express App instance
const app = express();

// 1. HTTP Security Headers (Helmet protects against signature leaking, clickjacking, MIME-sniffing)
app.use(helmet());

// 2. Strict CORS Origin whitelisting (Prevents Cross-Origin Resource Sharing leaks in production)
const allowedOrigins = [
  process.env.CLIENT_URL,
  'http://localhost:8080',
  'http://localhost:5000',
  'http://127.0.0.1:8080',
  'http://127.0.0.1:5000'
].filter(Boolean);

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (like mobile apps, curl, postman)
    if (!origin) return callback(null, true);
    
    if (allowedOrigins.indexOf(origin) !== -1 || process.env.NODE_ENV === 'development') {
      return callback(null, true);
    } else {
      return callback(new Error('Blocked by CORS security policy. Access denied.'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
}));

// 3. API Rate Limiting (Protects against DDoS and brute-force brute scans)
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 200, // Limit each IP to 200 requests per 15 minutes
  message: {
    success: false,
    message: 'Too many requests from this IP. Please try again in 15 minutes.',
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});
app.use(globalLimiter);

// Authentication rate limiter (Protects login & registration from dictionary brute-forcing)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30, // Limit each IP to 30 authentication attempts per 15 minutes
  message: {
    success: false,
    message: 'Too many authentication attempts. Please try again in 15 minutes.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/auth/register', authLimiter);
app.use('/api/auth/login', authLimiter);

// Chat APIs rate limiter (Protects message paging and conversations from flood spams)
const chatLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 chat operations per 15 minutes
  message: {
    success: false,
    message: 'Too many chat operations. Please try again in 15 minutes.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/chat', chatLimiter);

// 4. Request Payload Constraints (Protects against event-loop blocking and Out-of-Memory crashes)
app.use(express.json({ limit: '10kb' })); // Max body payload 10KB
app.use(express.urlencoded({ limit: '10kb', extended: true }));

// 5. MongoDB/NoSQL Injection Prevention (Recursively strips keys beginning with $ or containing .)
const sanitizeMongo = (value) => {
  if (value !== null && typeof value === 'object') {
    for (const key in value) {
      if (Object.prototype.hasOwnProperty.call(value, key)) {
        if (key.startsWith('$') || key.includes('.')) {
          delete value[key];
        } else {
          sanitizeMongo(value[key]);
        }
      }
    }
  }
  return value;
};

// 6. Custom Input Sanitization Middleware (Recursively strips HTML markup scripts to prevent Persistent XSS)
const sanitizeXSS = (value) => {
  if (typeof value === 'string') {
    return value
      .replace(/<[^>]*>/g, '') // Strips HTML elements: <script>, <iframe> etc
      .replace(/javascript:/gi, '') // Strips javascript pseudo-protocols
      .trim();
  }
  if (value !== null && typeof value === 'object') {
    for (const key in value) {
      if (Object.prototype.hasOwnProperty.call(value, key)) {
        value[key] = sanitizeXSS(value[key]);
      }
    }
  }
  return value;
};

// Attach in-place deep security sanitizers on incoming request bodies, queries, and params
app.use((req, res, next) => {
  if (req.body && typeof req.body === 'object') {
    sanitizeMongo(req.body);
    sanitizeXSS(req.body);
  }
  if (req.query && typeof req.query === 'object') {
    sanitizeMongo(req.query);
    sanitizeXSS(req.query);
  }
  if (req.params && typeof req.params === 'object') {
    sanitizeMongo(req.params);
    sanitizeXSS(req.params);
  }
  next();
});

// Serve API Routes
app.use('/api', apiRouter);

// Fallback Route for Undefined Resources (404 API Endpoint)
app.use((req, res, next) => {
  const error = new Error(`Cannot find requested route ${req.originalUrl} on this server.`);
  error.statusCode = 404;
  next(error);
});

// Central Error Interception Middleware
app.use(errorHandler);

module.exports = app;
