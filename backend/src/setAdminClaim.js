/*
  Small helper script to set the `admin` custom claim on a user.

  Usage:
    node src/setAdminClaim.js <uid> <true|false>

  Requires a Firebase service account JSON to be available and pointed
  at by the GOOGLE_APPLICATION_CREDENTIALS environment variable.
*/
const admin = require('firebase-admin');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Please set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON file path.');
  process.exit(1);
}

admin.initializeApp();

const uid = process.argv[2];
const flag = process.argv[3] === 'true';

if (!uid) {
  console.error('Usage: node src/setAdminClaim.js <uid> <true|false>');
  process.exit(1);
}

admin.auth().setCustomUserClaims(uid, { admin: flag })
  .then(() => {
    console.log(`Set admin=${flag} for uid=${uid}`);
    process.exit(0);
  })
  .catch((err) => {
    console.error('Error setting custom claim:', err);
    process.exit(2);
  });
