const express = require('express');
const router = express.Router();

const authRoutes = require('./authRoutes');
const chatRoutes = require('./chatRoutes');

// Healthcheck Route
router.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'Chat Application Backend service is running healthily.',
    timestamp: new Date(),
  });
});

// Resource Routing
router.use('/auth', authRoutes);
router.use('/chat', chatRoutes);

module.exports = router;
