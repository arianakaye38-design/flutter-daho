const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize the Admin SDK (uses service account when deployed)
admin.initializeApp();

// HTTP endpoint to set/unset the `admin` custom claim on a user.
// Security: Requires the caller to include a Firebase ID token in
// the `Authorization: Bearer <idToken>` header. The token must decode to a
// user that already has the `admin` custom claim. This avoids shared secrets
// and enforces admin-only access.
// Usage:
//  POST with JSON body { uid: '<uid>' , admin: true }
//  or { email: 'user@example.com', admin: true }
exports.setAdminClaim = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Only POST allowed');
    return;
  }

  // Require Authorization header with Bearer token
  const authHeader = req.header('Authorization') || req.header('authorization') || '';
  if (!authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Unauthorized: missing Authorization Bearer token' });
    return;
  }

  const idToken = authHeader.split(' ')[1];
  let caller;
  try {
    caller = await admin.auth().verifyIdToken(idToken);
  } catch (err) {
    console.error('verifyIdToken failed', err);
    res.status(401).json({ error: 'Unauthorized: invalid ID token' });
    return;
  }

  if (!caller || !caller.admin) {
    res.status(403).json({ error: 'Forbidden: caller is not an admin' });
    return;
  }

  const { uid, email, admin: isAdmin } = req.body || {};

  if (!uid && !email) {
    res.status(400).json({ error: 'Request must include `uid` or `email`' });
    return;
  }

  try {
    let targetUid = uid;
    if (!targetUid && email) {
      const user = await admin.auth().getUserByEmail(email);
      targetUid = user.uid;
    }

    await admin.auth().setCustomUserClaims(targetUid, { admin: !!isAdmin });

    res.json({ success: true, uid: targetUid, admin: !!isAdmin });
  } catch (err) {
    console.error('setAdminClaim error', err);
    res.status(500).json({ error: String(err) });
  }
});
