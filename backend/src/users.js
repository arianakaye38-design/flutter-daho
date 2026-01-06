// Simple in-memory user store for demo/testing purposes
// Replace with a database in production

const users = new Map(); // key: id, value: user object
let nextId = 1;

function createUser({ email, username, passwordHash }) {
  const id = nextId++;
  const now = Date.now();
  const user = {
    id,
    email: email ? email.toLowerCase() : null,
    username: username ? username.toLowerCase() : null,
    passwordHash,
    failedAttempts: 0,
    lockedUntil: null,
    createdAt: now,
    updatedAt: now,
  };
  users.set(id, user);
  return { ...user };
}

function findByEmailOrUsername(identifier) {
  if (!identifier) return null;
  const idLower = identifier.toLowerCase();
  for (const user of users.values()) {
    if ((user.email && user.email === idLower) || (user.username && user.username === idLower)) {
      return { ...user };
    }
  }
  return null;
}

function getById(id) {
  const u = users.get(id);
  return u ? { ...u } : null;
}

function incrementFailed(id) {
  const u = users.get(id);
  if (!u) return;
  u.failedAttempts = (u.failedAttempts || 0) + 1;
  u.updatedAt = Date.now();
}

function resetFailed(id) {
  const u = users.get(id);
  if (!u) return;
  u.failedAttempts = 0;
  u.lockedUntil = null;
  u.updatedAt = Date.now();
}

function lockUser(id, durationMs) {
  const u = users.get(id);
  if (!u) return;
  u.lockedUntil = Date.now() + durationMs;
  u.updatedAt = Date.now();
}

function setPasswordHash(id, passwordHash) {
  const u = users.get(id);
  if (!u) return;
  u.passwordHash = passwordHash;
  u.updatedAt = Date.now();
}

function existsEmailOrUsername(email, username) {
  const e = email ? email.toLowerCase() : null;
  const uName = username ? username.toLowerCase() : null;
  for (const u of users.values()) {
    if ((e && u.email === e) || (uName && u.username === uName)) return true;
  }
  return false;
}

function clearAll() {
  users.clear();
  nextId = 1;
}

module.exports = {
  createUser,
  findByEmailOrUsername,
  getById,
  incrementFailed,
  resetFailed,
  lockUser,
  setPasswordHash,
  existsEmailOrUsername,
  clearAll,
};
