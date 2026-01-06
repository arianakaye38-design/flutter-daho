module.exports = {
  PORT: process.env.PORT || 4000,
  JWT_SECRET: process.env.JWT_SECRET || 'dev-secret',
  TOKEN_EXPIRY: process.env.TOKEN_EXPIRY || '1h',
  // Argon2 params (reasonable defaults)
  ARGON2: {
    type: undefined, // leave to argon2 default (argon2id when available)
    timeCost: parseInt(process.env.ARGON2_TIME_COST || '3', 10),
    memoryCost: parseInt(process.env.ARGON2_MEMORY_COST || '65536', 10),
    parallelism: parseInt(process.env.ARGON2_PARALLELISM || '1', 10)
  },
  // Rate limiting / lockout
  RATE_LIMIT_WINDOW_MS: parseInt(process.env.RATE_LIMIT_WINDOW_MS || String(15 * 60 * 1000), 10),
  RATE_LIMIT_MAX: parseInt(process.env.RATE_LIMIT_MAX || '100', 10),
  MAX_FAILED_ATTEMPTS: parseInt(process.env.MAX_FAILED_ATTEMPTS || '5', 10),
  LOCKOUT_MS: parseInt(process.env.LOCKOUT_MS || String(15 * 60 * 1000), 10),
};
