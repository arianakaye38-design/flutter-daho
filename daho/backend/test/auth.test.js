const request = require('supertest');
const express = require('express');
const authRoutes = require('../src/routes/auth');
const { ensureDummyHash } = require('../src/utils/dummyHash');
const users = require('../src/users');
const config = require('../src/config');

let app;

beforeAll(async () => {
  await ensureDummyHash();
  app = express();
  app.use(express.json());
  app.use('/api', authRoutes);
});

beforeEach(() => {
  // Reset in-memory users
  users.clearAll();
});

test('register new user stores hashed password and returns 201', async () => {
  const res = await request(app).post('/api/register').send({
    email: 'test@example.com',
    username: 'testuser',
    password: 'StrongPass1!',
    passwordConfirm: 'StrongPass1!'
  });
  expect(res.status).toBe(201);
  expect(res.body.email).toBe('test@example.com');
  // ensure stored user has a hash
  const u = users.findByEmailOrUsername('test@example.com');
  expect(u).toBeTruthy();
  expect(typeof u.passwordHash).toBe('string');
  expect(u.passwordHash.length).toBeGreaterThan(10);
});

test('register with weak password returns 400', async () => {
  const res = await request(app).post('/api/register').send({
    email: 'weak@example.com',
    username: 'weakuser',
    password: 'abc',
    passwordConfirm: 'abc'
  });
  expect(res.status).toBe(400);
  expect(res.body.error).toMatch(/Password must be at least/);
});

test('register duplicate returns 400 with generic message', async () => {
  await request(app).post('/api/register').send({
    email: 'dup@example.com',
    username: 'dupuser',
    password: 'StrongPass1!',
    passwordConfirm: 'StrongPass1!'
  });
  const res = await request(app).post('/api/register').send({
    email: 'dup@example.com',
    username: 'dupuser2',
    password: 'StrongPass1!',
    passwordConfirm: 'StrongPass1!'
  });
  expect([400, 409]).toContain(res.status);
  expect(res.body.error).toMatch(/Registration failed/);
});

test('login success returns token', async () => {
  await request(app).post('/api/register').send({
    email: 'login@example.com',
    username: 'loginuser',
    password: 'StrongPass1!',
    passwordConfirm: 'StrongPass1!'
  });
  const res = await request(app).post('/api/login').send({
    identifier: 'loginuser',
    password: 'StrongPass1!'
  });
  expect(res.status).toBe(200);
  expect(res.body.token).toBeTruthy();
});

test('login wrong password returns 401 and no token', async () => {
  await request(app).post('/api/register').send({
    email: 'wpass@example.com',
    username: 'wpass',
    password: 'StrongPass1!',
    passwordConfirm: 'StrongPass1!'
  });
  const res = await request(app).post('/api/login').send({
    identifier: 'wpass',
    password: 'WrongPassword!'
  });
  expect(res.status).toBe(401);
  expect(res.body.token).toBeFalsy();
});

test('login non-existent returns same 401 message', async () => {
  const res = await request(app).post('/api/login').send({
    identifier: 'doesnotexist',
    password: 'Whatever1!'
  });
  expect(res.status).toBe(401);
  expect(res.body.error).toBe('Invalid username or password.');
});

test('exceed failed attempts locks account and returns 429', async () => {
  // shorten lockout for test
  const originalMax = config.MAX_FAILED_ATTEMPTS;
  const originalLockout = config.LOCKOUT_MS;
  config.MAX_FAILED_ATTEMPTS = 3;
  config.LOCKOUT_MS = 1000; // 1s

  await request(app).post('/api/register').send({
    email: 'lock@example.com',
    username: 'lockuser',
    password: 'StrongPass1!',
    passwordConfirm: 'StrongPass1!'
  });

  for (let i = 0; i < 3; i++) {
    await request(app).post('/api/login').send({ identifier: 'lockuser', password: 'BadPass1!' });
  }
  const res = await request(app).post('/api/login').send({ identifier: 'lockuser', password: 'BadPass1!' });
  expect(res.status).toBe(429);

  // restore
  config.MAX_FAILED_ATTEMPTS = originalMax;
  config.LOCKOUT_MS = originalLockout;
});
