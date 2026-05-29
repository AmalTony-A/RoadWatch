const path = require('path');
const fs = require('fs');
const multer = require('multer');

const uploadDir = path.resolve(process.cwd(), process.env.UPLOAD_DIR || 'uploads');
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const stamp = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    const ext = path.extname(file.originalname || '').toLowerCase();
    const safeExt = ext === '.jpeg' ? '.jpg' : ext;
    cb(null, `${stamp}${safeExt}`);
  },
});

const fileFilter = (_req, file, cb) => {
  const allowed = ['image/jpeg', 'image/png', 'image/webp'];
  if (allowed.includes(file.mimetype)) {
    cb(null, true);
    return;
  }
  cb(new Error('Only JPEG, PNG, and WEBP files are allowed'));
};

module.exports = multer({
  storage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 },
});
