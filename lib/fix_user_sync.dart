import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

/// EMERGENCY FIX: Create missing Firestore user documents for existing auth accounts
///
/// Run: flutter run lib/fix_user_sync.dart -d chrome
///
/// This fixes the "white screen" issue caused by auth accounts without Firestore docs

void main() async {
  debugPrint('🔧 Fixing user sync issues...\n');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final db = FirebaseFirestore.instance;

  // Define the users that need Firestore documents
  // Get UIDs from Firebase Console → Authentication → Users
  final usersToCreate = [
    {
      'uid': 'Jhfwqrk0zaPUtgpRSctxLGLV9Mj1', // admin@daho.app
      'email': 'admin@daho.app',
      'type': 'admin',
    },
    {
      'uid': 'VaX8NpAcjZcj2UhWPoSvz07', // owner@gmail.com
      'email': 'owner@gmail.com',
      'type': 'owner',
    },
    {
      'uid': 'lyS2fVxbWLNGBHs3mkHkbu6', // courier@gmail.com
      'email': 'courier@gmail.com',
      'type': 'courier',
    },
    {
      'uid':
          'uG88VvYAcYN9U0kD2D2gBJ', // customer@gmail.com (might already exist)
      'email': 'customer@gmail.com',
      'type': 'customer',
    },
  ];

  debugPrint('Creating missing user documents...\n');

  for (final user in usersToCreate) {
    try {
      // Check if document already exists
      final doc = await db.collection('users').doc(user['uid']).get();

      if (doc.exists) {
        debugPrint('✓ ${user['email']} - already exists');
        continue;
      }

      // Create the document
      await db.collection('users').doc(user['uid']).set({
        'email': user['email'],
        'type': user['type'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Created: ${user['email']} (${user['type']})');
    } catch (e) {
      debugPrint('❌ Failed: ${user['email']} - $e');
    }
  }

  debugPrint('\n🎉 User sync fix complete!');
  debugPrint('\n💡 Next: Try logging in to the app again');
}
