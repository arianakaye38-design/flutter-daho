import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

/// Run this file ONCE to populate Firestore with test data
///
/// To run: flutter run lib/seed_data.dart
///
/// This creates:
/// - 2 pasalubong centers
/// - 4 products
/// - 1 courier profile
///
/// IMPORTANT: Update the UIDs and admin credentials below!

void main() async {
  debugPrint('🌱 Starting Firestore seed...');

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('✅ Firebase initialized');

  // Sign in as admin to get write permissions
  debugPrint('🔐 Signing in as admin...');
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'admin@daho.app',
      password: 'adminpassword',
    );
    debugPrint('✅ Signed in as admin');
  } catch (e) {
    debugPrint('❌ Admin sign-in failed: $e');
    debugPrint(
      '💡 Update the email/password in seed_data.dart or fix security rules',
    );
    return;
  }

  await seedFirestoreData();

  // Sign out after seeding
  await FirebaseAuth.instance.signOut();
  debugPrint('🎉 Seed complete! Check Firebase Console.');
}

Future<void> seedFirestoreData() async {
  final db = FirebaseFirestore.instance;

  // ============================================
  // STEP 1: Get User UIDs from Firebase Console
  // ============================================

  // TODO: Replace these with ACTUAL UIDs from Firebase Console → Authentication → Users
  // Click on each user to see their UID, then paste here:

  const String ownerUID = 'VaX8NpAcjZcj2UhWPoSvz07'; // owner@gmail.com UID
  const String courierUID = 'lyS2fVxbWLNGBHs3mkHkbu6'; // courier@gmail.com UID

  debugPrint('\n📍 Creating pasalubong centers...');

  // ============================================
  // STEP 2: Create Pasalubong Centers
  // ============================================

  try {
    // JMM Bakeshop
    await db.collection('pasalubong_centers').doc('jmm-bakeshop').set({
      'name': 'JMM Bakeshop',
      'ownerId': ownerUID,
      'location': const GeoPoint(10.59806876046459, 122.59228907843912),
      'address': 'Alibhon, Jordan, Guimaras',
      'phone': '+639171234567',
      'email': 'owner@gmail.com',
      'operatingHours': '8:00 AM - 6:00 PM',
      'isApproved': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Created JMM Bakeshop');

    // Boboy's Delicacies
    await db.collection('pasalubong_centers').doc('boboys-delicacies').set({
      'name': "Boboy's Delicacies",
      'ownerId': ownerUID, // Same owner for now
      'location': const GeoPoint(10.60749434917473, 122.59313057862323),
      'address': 'Jordan, Guimaras',
      'phone': '+639171234568',
      'email': 'owner@gmail.com',
      'operatingHours': '9:00 AM - 7:00 PM',
      'isApproved': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Created Boboy\'s Delicacies');
  } catch (e) {
    debugPrint('❌ Error creating pasalubong centers: $e');
  }

  debugPrint('\n🍬 Creating products...');

  // ============================================
  // STEP 3: Create Products
  // ============================================

  try {
    // Product 1: Mango Piaya
    await db.collection('products').add({
      'name': 'Mango Piaya',
      'price': 25.0,
      'centerId': 'jmm-bakeshop',
      'ownerId': ownerUID,
      'description': '4pcs x 35g - Sweet mango-filled pastry',
      'imageUrl': '', // TODO: Add actual image URL later
      'stock': 50,
      'isAvailable': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Created Mango Piaya');

    // Product 2: Dried Mangoes
    await db.collection('products').add({
      'name': 'Dried Mangoes',
      'price': 180.0,
      'centerId': 'jmm-bakeshop',
      'ownerId': ownerUID,
      'description': 'Premium dried mangoes from Guimaras',
      'imageUrl': '',
      'stock': 30,
      'isAvailable': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Created Dried Mangoes');

    // Product 3: Biscocho
    await db.collection('products').add({
      'name': 'Biscocho',
      'price': 120.0,
      'centerId': 'boboys-delicacies',
      'ownerId': ownerUID,
      'description': 'Traditional biscocho bread',
      'imageUrl': '',
      'stock': 40,
      'isAvailable': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Created Biscocho');

    // Product 4: Ube Pastillas
    await db.collection('products').add({
      'name': 'Ube Pastillas',
      'price': 200.0,
      'centerId': 'boboys-delicacies',
      'ownerId': ownerUID,
      'description': 'Sweet ube pastillas candy',
      'imageUrl': '',
      'stock': 25,
      'isAvailable': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Created Ube Pastillas');
  } catch (e) {
    debugPrint('❌ Error creating products: $e');
  }

  debugPrint('\n🚚 Creating courier profile...');

  // ============================================
  // STEP 4: Create Courier Profile
  // ============================================

  try {
    await db.collection('couriers').doc(courierUID).set({
      'userId': courierUID,
      'name': 'Courier User',
      'currentLocation': const GeoPoint(10.6036, 122.5927), // Center of Alibhon
      'isOnline': false,
      'isAvailable': true,
      'activeOrderId': null,
      'vehicleType': 'motorcycle',
      'rating': 5.0,
      'completedOrders': 0,
      'lastLocationUpdate': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Created courier profile');
  } catch (e) {
    debugPrint('❌ Error creating courier profile: $e');
  }

  debugPrint('\n📊 Summary:');
  debugPrint('  • 2 pasalubong centers created');
  debugPrint('  • 4 products created');
  debugPrint('  • 1 courier profile created');
  debugPrint('\n💡 Next steps:');
  debugPrint('  1. Go to Firebase Console → Firestore → Data');
  debugPrint('  2. Verify all collections exist');
  debugPrint('  3. Run the app and test order flow');
}
