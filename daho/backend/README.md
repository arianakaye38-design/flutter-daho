# Daho Auth Backend (minimal)

This folder contains a minimal Express-based authentication service used for local testing and examples.

Features:
- Registration with Argon2id password hashing
- Login with Argon2 verify and JWT token issuance
- Per-IP rate limiting (express-rate-limit)
- Per-account failed-attempt tracking and lockout
- Generic error messages to avoid user enumeration

Quick start

1. From the `backend` folder install dependencies:

```powershell
npm install
```

2. Run tests:

```powershell
npm test
```

3. Start server:

```powershell
npm start
```

Configuration (via environment variables)
- JWT_SECRET: secret for signing JWTs (default: dev-secret)
- PORT: server port (default: 4000)
- MAX_FAILED_ATTEMPTS: number of consecutive failed attempts before lockout (default: 5)
- LOCKOUT_MS: lockout duration in ms (default: 15 * 60 * 1000)
- RATE_LIMIT_WINDOW_MS: IP rate-limit window (default: 15 minutes)
- RATE_LIMIT_MAX: max requests per window per IP (default: 100)
- ARGON2_TIME_COST: argon2 timeCost (default: 3)
- ARGON2_MEMORY_COST: argon2 memoryCost (default: 65536)
- ARGON2_PARALLELISM: argon2 parallelism (default: 1)

Notes
- This is an example implementation intended for local development and testing. For production you should use a persistent database and a fast in-memory store like Redis for counters and rate limits, enable HTTPS, rotate JWT secrets, and tune Argon2 costs according to your environment.
