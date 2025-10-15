const express = require('express');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');
const { Client } = require('pg');
const AWS = require('aws-sdk');
const multer = require('multer');

const app = express();
app.use(bodyParser.json());
const upload = multer();

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.PAYLOAD_JWT_SECRET || 'dev-secret';

// DB health
const dbClient = new Client({
  connectionString: process.env.DATABASE_URL ||
    `postgresql://payload:payloadpass@postgres:5432/payloaddb`
});
dbClient.connect().catch(err => console.error('DB connect error', err));

// S3 (MinIO) config (optional)
let s3 = null;
if (process.env.S3_ENDPOINT) {
  s3 = new AWS.S3({
    accessKeyId: process.env.S3_ACCESS_KEY || 'minioadmin',
    secretAccessKey: process.env.S3_SECRET_KEY || 'minioadmin',
    endpoint: process.env.S3_ENDPOINT || 'http://minio:9000',
    s3ForcePathStyle: true,
    signatureVersion: 'v4',
  });
}

function currentTenant(req) {
  // Simple Host → tenant resolution demo
  const host = (req.headers.host || '').split(':')[0];
  if (host === 'cms.localhost') return 'tenant_main';
  // support tenant1.localhost -> tenant1
  if (/^(.+)\.localhost$/.test(host)) {
    return host.split('.')[0];
  }
  return 'unknown';
}

// Public payload API (headless)
app.get('/payload/health', async (req, res) => {
  const tenant = currentTenant(req);
  try {
    const dbRes = await dbClient.query('SELECT 1');
    res.json({ status: 'ok', tenant, db: !!dbRes.rows.length });
  } catch (e) {
    res.status(500).json({ status: 'fail', error: e.message });
  }
});

// Admin login (issue JWT) — demo only
app.post('/admin/login', (req, res) => {
  const { user, pass } = req.body || {};
  // demo: accept 'admin' / 'password'
  if (user === 'admin' && pass === 'password') {
    const token = jwt.sign({ sub: 'admin' }, JWT_SECRET, { expiresIn: '2h' });
    return res.json({ token });
  }
  return res.status(401).json({ error: 'invalid credentials' });
});

// Protect admin routes
function requireAdmin(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: 'unauthorized' });
  const m = auth.match(/^Bearer (.+)$/);
  if (!m) return res.status(401).json({ error: 'unauthorized' });
  try {
    const payload = jwt.verify(m[1], JWT_SECRET);
    req.user = payload;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'invalid token' });
  }
}

// Admin UI (mock)
app.get('/admin', requireAdmin, (req, res) => {
  res.send(`<h1>Payload Admin UI (mock)</h1><p>Tenant: ${currentTenant(req)}</p>`);
});

// Example content API
app.get('/payload/articles', (req, res) => {
  const tenant = currentTenant(req);
  res.json({
    tenant,
    articles: [
      { id: 1, title: `Hello from ${tenant}` },
      { id: 2, title: 'Another article' }
    ]
  });
});

// Media upload (stores to S3/MinIO if available)
app.post('/payload/upload', requireAdmin, upload.single('file'), async (req, res) => {
  if (!s3) return res.status(500).json({ error: 'S3 not configured in env' });
  const file = req.file;
  if (!file) return res.status(400).json({ error: 'no file' });
  const key = `${Date.now()}-${file.originalname}`;
  try {
    await s3.putObject({
      Bucket: process.env.S3_BUCKET || 'payload-media',
      Key: key,
      Body: file.buffer,
      ContentType: file.mimetype
    }).promise();
    const url = `${process.env.S3_PUBLIC_URL || 'http://localhost:9000'}/${process.env.S3_BUCKET || 'payload-media'}/${key}`;
    res.json({ url });
  } catch (err) {
    console.error('upload error', err);
    res.status(500).json({ error: err.message });
  }
});

// Basic index
app.get('/', (req, res) => {
  res.json({
    service: 'payload-mock',
    tenant: currentTenant(req),
    docs: {
      health: '/payload/health',
      articles: '/payload/articles',
      admin_login: '/admin/login (POST {user,pass})',
      admin_ui: '/admin (GET with Bearer token)'
    }
  });
});

app.listen(PORT, () => {
  console.log(`Payload-mock listening on ${PORT}`);
});
