import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth_service.dart';

// Firebase-backed auth service with a graceful fallback to the in-memory
// `AuthService` when Firebase isn't configured or an operation fails.
class FirebaseAuthService {
  FirebaseAuthService._private();
  static final FirebaseAuthService instance = FirebaseAuthService._private();

  /// Registers a new user in Firebase Auth and records the `userType` in
  /// Firestore under `users/{uid}`. Returns `null` on success or an
  /// error message string on failure. If Firebase is unavailable the
  /// in-memory `AuthService` will be used as a fallback (same contract).
  Future<String?> register(
    String email,
    String password,
    String userType,
  ) async {
    try {
      // Create user with Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user?.uid;
      if (uid != null) {
        // Persist the user type in Firestore for later lookups on sign-in
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': email.trim().toLowerCase(),
          'type': userType,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return null;
    } on FirebaseAuthException catch (e) {
      // Map Firebase error to a user-friendly message
      return e.message ?? 'Authentication error';
    } catch (e) {
      // If anything else goes wrong (Firebase not initialized, missing
      // platform config, etc.) fall back to the in-memory service.
      try {
        return AuthService.instance.register(email, password, userType);
      } catch (_) {
        return 'Registration failed';
      }
    }
  }

  /// Attempts to sign in. Returns the `userType` on success (e.g. 'customer',
  /// 'owner', 'courier'), or `null` on failure (which signals the UI to show
  /// the "create account" prompt). Falls back to the in-memory service when
  /// Firebase is not available.
  Future<String?> login(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['type'] is String) {
            return data['type'] as String;
          }
        }
        // If no Firestore record exists, fall back to a default customer type
        return 'customer';
      }

      return null;
    } on FirebaseAuthException catch (_) {
      // For auth errors like wrong-password / user-not-found return null so
      // the UI will show the "create account" dialog.
      return null;
    } catch (e) {
      // Firebase not available or unexpected error: try in-memory fallback.
      try {
        return AuthService.instance.login(email, password);
      } catch (_) {
        return null;
      }
    }
  }

  /// Optionally expose sign-out for other parts of the app.
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // ignore - fallback/no-op
    }
  }
}
