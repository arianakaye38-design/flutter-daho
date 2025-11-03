// Generate a dummy hash at startup to avoid timing differences when user not found
const argon2 = require('argon2');
const config = require('../config');

let DUMMY_HASH = null;

async function ensureDummyHash() {
  if (DUMMY_HASH) return DUMMY_HASH;
  // Use configured ARGON2 params but enforce a safe minimum for timeCost
  const timeCost = Math.max(2, parseInt(config.ARGON2.timeCost || 2, 10));
  const memoryCost = parseInt(config.ARGON2.memoryCost || 1024, 10);
  const parallelism = parseInt(config.ARGON2.parallelism || 1, 10);
  DUMMY_HASH = await argon2.hash('DummyPassword!123', { timeCost, memoryCost, parallelism });
  return DUMMY_HASH;
}

function getDummyHash() {
  if (!DUMMY_HASH) throw new Error('Dummy hash not initialized');
  return DUMMY_HASH;
}

module.exports = { ensureDummyHash, getDummyHash };
