// Run this script with: node check_messages.js
const admin = require('./backend/node_modules/firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./backend/functions/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkMessages() {
  console.log('Checking messages collection...\n');

  const messagesSnapshot = await db.collection('messages').get();

  console.log(`Found ${messagesSnapshot.size} conversations\n`);

  messagesSnapshot.forEach(doc => {
    const data = doc.data();
    console.log(`Document ID: ${doc.id}`);
    console.log(`  ownerId: ${data.ownerId || 'MISSING'}`);
    console.log(`  ownerName: ${data.ownerName || 'MISSING'}`);
    console.log(`  courierId: ${data.courierId || 'MISSING'}`);
    console.log(`  courierName: ${data.courierName || 'MISSING'}`);
    console.log(`  userId: ${data.userId || 'MISSING'}`);
    console.log(`  userName: ${data.userName || 'MISSING'}`);
    console.log(`  lastMessage: ${data.lastMessage || ''}`);
    console.log(`  deletedByOwner: ${data.deletedByOwner}`);
    console.log(`  deletedByCourier: ${data.deletedByCourier}`);
    console.log('');
  });

  console.log('\n--- Summary ---');
  console.log('Looking for owner-courier conversations...');
  
  const ownerCourierConvos = messagesSnapshot.docs.filter(doc => {
    const data = doc.data();
    return data.ownerId && data.courierId;
  });

  console.log(`Found ${ownerCourierConvos.length} owner-courier conversations`);
  
  ownerCourierConvos.forEach(doc => {
    const data = doc.data();
    console.log(`  - ${doc.id}: Owner(${data.ownerName}) <-> Courier(${data.courierName})`);
    if (!data.courierId) {
      console.log(`    ⚠️  WARNING: Missing courierId!`);
    }
  });

  process.exit(0);
}

checkMessages().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
