/*
  Helper script to set the `admin` custom claim using a user's email.

  Usage:
    node src/setAdminClaimByEmail.js user@example.com true

  Requires GOOGLE_APPLICATION_CREDENTIALS to be set to a service account JSON
  with permissions to manage users (Firebase Admin SDK).
*/
const admin = require('firebase-admin');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Please set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON file path.');
  process.exit(1);
}

admin.initializeApp();

const email = process.argv[2];
const flag = process.argv[3] === 'true';

if (!email) {
  console.error('Usage: node src/setAdminClaimByEmail.js <email> <true|false>');
  process.exit(1);
}

admin.auth().getUserByEmail(email)
  .then((userRecord) => {
    const uid = userRecord.uid;
    return admin.auth().setCustomUserClaims(uid, { admin: flag })
      .then(() => {
        console.log(`Set admin=${flag} for ${email} (uid=${uid})`);
        process.exit(0);
      });
  })
  .catch((err) => {
    console.error('Error:', err);
    process.exit(2);
  });
