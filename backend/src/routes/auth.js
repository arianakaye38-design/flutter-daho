const express = require('express');
const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const { ensureDummyHash, getDummyHash } = require('../utils/dummyHash');
const users = require('../users');
const config = require('../config');

const router = express.Router();

function validatePasswordStrength(password) {
  const minLen = 10;
  if (!password || password.length < minLen) return `Password must be at least ${minLen} characters.`;
  // simple checks; configurable/extendable
  const hasLetter = /[A-Za-z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  const hasSymbol = /[^A-Za-z0-9]/.test(password);
  if (!hasLetter || !hasNumber || !hasSymbol) return 'Password must contain letters, numbers, and symbols.';
  return null;
}

router.post('/register', async (req, res) => {
  const { email, username, password, passwordConfirm } = req.body || {};
  if (!password || !passwordConfirm || !(email || username)) {
    return res.status(400).json({ error: 'Missing required fields.' });
  }
  if (password !== passwordConfirm) return res.status(400).json({ error: 'Passwords do not match.' });

  const pwErr = validatePasswordStrength(password);
  if (pwErr) return res.status(400).json({ error: pwErr });

  // Do not reveal which field already exists in the public message
  if (users.existsEmailOrUsername(email, username)) {
    return res.status(400).json({ error: 'Registration failed. Please check your details or reset password if you already have an account.' });
  }

  try {
    const hash = await argon2.hash(password, {
      timeCost: config.ARGON2.timeCost,
      memoryCost: config.ARGON2.memoryCost,
      parallelism: config.ARGON2.parallelism,
    });
    const user = users.createUser({ email, username, passwordHash: hash });
    // Return minimal user info
    return res.status(201).json({ id: user.id, email: user.email, username: user.username });
  } catch (err) {
    console.error('Registration error', err);
    return res.status(500).json({ error: 'Registration failed.' });
  }
});

router.post('/login', async (req, res) => {
  const { identifier, password } = req.body || {};
  if (!identifier || !password) return res.status(400).json({ error: 'Missing required fields.' });

  const user = users.findByEmailOrUsername(identifier);

  // If user doesn't exist, verify against dummy hash to equalize timing
  const hashToCompare = user ? user.passwordHash : getDummyHash();

  // Check lockout
  if (user && user.lockedUntil && Date.now() < user.lockedUntil) {
    return res.status(429).json({ error: 'Too many failed attempts. Try again later.' });
  }

  let verified = false;
  try {
    verified = await argon2.verify(hashToCompare, password);
  } catch (err) {
    // Verification errors treated as a failed attempt
    verified = false;
  }

  if (!user || !verified) {
    // If user exists, increment failures and lock if threshold reached
    if (user) {
      users.incrementFailed(user.id);
      if (user.failedAttempts + 1 >= config.MAX_FAILED_ATTEMPTS) {
        users.lockUser(user.id, config.LOCKOUT_MS);
        console.warn(`User ${user.id} locked due to failed attempts`);
        return res.status(429).json({ error: 'Too many failed attempts. Try again later.' });
      }
    }

    // Log failed attempt (do not log raw password)
    console.warn('Failed login attempt for identifier:', identifier);
    return res.status(401).json({ error: 'Invalid username or password.' });
  }

  // Successful login
  users.resetFailed(user.id);
  const token = jwt.sign({ sub: user.id }, config.JWT_SECRET, { expiresIn: config.TOKEN_EXPIRY });
  // Return token (client can store it), in production set Secure, HttpOnly cookie
  return res.status(200).json({ token });
});

module.exports = router;
