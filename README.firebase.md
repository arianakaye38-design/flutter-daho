Firebase admin setup (creating admin users)
=========================================

This small guide shows two safe ways to give a user an "admin" role using
Firebase custom claims. Use the server-side approach — do not rely on client
code for authorization.

1) Quick helper (local Node script)
----------------------------------

Prerequisites
- A Firebase service account JSON file (create in Firebase Console → Project
  Settings → Service accounts → Generate new private key).
- Node.js installed locally.

Steps
1. Set the environment variable pointing to the service account JSON:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\path\to\service-account.json'
```

2. From the `backend` folder install deps (we added `firebase-admin`):

```powershell
cd backend
npm install
```

3. Run the helper to set the admin claim for a user UID:

```powershell
# set admin
node src/setAdminClaim.js <UID> true

# remove admin
node src/setAdminClaim.js <UID> false
```

Where `<UID>` is the Firebase Authentication UID of the user (you can get
this from the Firebase Console Users list or via the Admin SDK).

You can also set the claim by email using the helper script added to
`backend/src/setAdminClaimByEmail.js`:

```powershell
node src/setAdminClaimByEmail.js user@example.com true
```

This looks up the user by email, then sets the custom claim.

2) Cloud Function (example)
---------------------------

You can also provide a small Cloud Function (HTTP or callable) that sets the
custom claim. Keep this function protected (only callable by existing admins or
via a secure backend). Example (Node.js / firebase-functions):

```js
// index.js (Cloud Functions)
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Callable function that sets the 'admin' custom claim.
// Caller must be an existing admin — this example checks callable auth
// token claims and denies if caller is not admin.
exports.setAdminClaim = functions.https.onCall(async (data, context) => {
  // Security: ensure the caller is authenticated and is an admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Request has no auth.');
  }
  const callerClaims = context.auth.token || {};
  if (!callerClaims.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can set admin claims.');
  }

  const { uid, makeAdmin } = data;
  if (!uid || typeof makeAdmin !== 'boolean') {
    throw new functions.https.HttpsError('invalid-argument', 'Missing args');
  }

  await admin.auth().setCustomUserClaims(uid, { admin: makeAdmin });
  return { success: true };
});
```

Notes
- After calling `setCustomUserClaims` you should force the user's ID token to
  refresh on the client (call `getIdToken(true)`) so new claims are visible.
- Custom claims are the recommended (secure) way to express roles like
  "admin". Always enforce role checks server-side before performing
  privileged actions.

Troubleshooting
- If you see permission errors when running the local script, confirm the
  `GOOGLE_APPLICATION_CREDENTIALS` path and that the service account has the
  `Firebase Admin` permissions.

## Production Safety and Admin Claims

Important: Do NOT ship any hard-coded admin account or backdoor in production builds. The codebase deliberately seeds an in-memory admin account only when running in debug mode (`kDebugMode`) for local development and testing. That in-memory account is not persisted to Firebase and will not exist in production.

Recommended secure workflow to grant admin privileges:

- Use the server-side Firebase Admin SDK (trusted environment) to set the `admin` custom claim for a user. You can use the helper scripts in `backend/` with a service account, or deploy a controlled Cloud Function that performs the assignment only when authorized.

This repository includes a basic HTTP Cloud Function at `backend/functions/index.js` named `setAdminClaim`.

Security model (current):

- The function requires the caller to include a Firebase ID token in the `Authorization: Bearer <idToken>` header. The token must decode to a user that already has the `admin` custom claim. This enforces that only existing admins may call the function.

Example JSON body:

```json
{ "email": "alice@example.com", "admin": true }
```

Example PowerShell call (replace values):

```powershell
#$idToken should be obtained by signing in an existing admin user in your client
#$idToken = '<ID_TOKEN_FROM_ADMIN_CLIENT>'
$url = 'https://us-central1-<PROJECT>.cloudfunctions.net/setAdminClaim'
$headers = @{ 'Authorization' = "Bearer $idToken" }
$body = @{ email = 'alice@example.com'; admin = $true } | ConvertTo-Json
Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType 'application/json'
```

Deployment notes:

- From `backend/functions` run `npm install`, then deploy functions with the Firebase CLI:

```powershell
cd backend/functions
npm install
cd ../..
firebase deploy --only functions
```

- For the very first administrative assignment (bootstrap), you can use the local helper scripts with a service account (see earlier section). Example:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\path\to\service-account.json'
node backend/src/setAdminClaimByEmail.js alice@example.com true
```

- After setting custom claims, clients must refresh their ID token to observe the new `admin` claim (e.g., call `getIdTokenResult(true)` or sign out and sign back in).

If you'd like, I can further harden the function (for example: require callable auth tokens, log audit records, or integrate with an allowlist). The current approach avoids shared secrets and relies on Firebase Auth's admin claims model.
