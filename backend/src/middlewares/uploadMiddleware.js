const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const UPLOAD_DIR = path.join(__dirname, '../../public/uploads');

// Create uploads directory if it doesn't exist
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'video/mp4',
  'video/webm',
  'video/quicktime',
]);

const MAX_IMAGE_SIZE = 10 * 1024 * 1024;  // 10 MB
const MAX_VIDEO_SIZE = 200 * 1024 * 1024; // 200 MB

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
  filename: (_req, file, cb) => {
    const randomHex = crypto.randomBytes(16).toString('hex');
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${randomHex}${ext}`);
  },
});

const fileFilter = (_req, file, cb) => {
  if (ALLOWED_MIME_TYPES.has(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Unsupported file type. Allowed: jpeg, png, gif, webp, mp4, webm, mov.'));
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    // Maximum cap — per-type enforcement happens in the route handler
    fileSize: MAX_VIDEO_SIZE,
  },
});

// Enforce per-type size caps after multer stores the file
const enforceSizeLimit = (req, res, next) => {
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'No file uploaded.' });
  }

  const isImage = req.file.mimetype.startsWith('image/');
  const limit = isImage ? MAX_IMAGE_SIZE : MAX_VIDEO_SIZE;

  if (req.file.size > limit) {
    fs.unlink(req.file.path, () => {});
    const label = isImage ? '10 MB' : '200 MB';
    return res.status(413).json({
      success: false,
      message: `File too large. Maximum allowed size for this type is ${label}.`,
    });
  }

  next();
};

module.exports = { upload, enforceSizeLimit };
