const express = require('express');
const helmet = require('helmet');
const cookieParser = require('cookie-parser');
const rateLimit = require('express-rate-limit');
const authRoutes = require('./routes/auth');
const config = require('./config');
const { ensureDummyHash } = require('./utils/dummyHash');

async function start() {
  await ensureDummyHash();

  const app = express();
  app.use(helmet());
  app.use(express.json());
  app.use(cookieParser());

  // Simple IP rate limiter
  const limiter = rateLimit({
    windowMs: config.RATE_LIMIT_WINDOW_MS,
    max: config.RATE_LIMIT_MAX,
  });
  app.use(limiter);

  app.use('/api', authRoutes);

  app.get('/', (req, res) => res.json({ ok: true }));

  const port = config.PORT;
  app.listen(port, () => console.log(`Auth server listening on ${port}`));
}

start().catch((err) => {
  console.error('Failed to start server', err);
  process.exit(1);
});
