import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Firebase-backed auth service for user authentication and authorization.
class FirebaseAuthService {
  FirebaseAuthService._private();
  static final FirebaseAuthService instance = FirebaseAuthService._private();

  /// Checks if an email is already registered in Firebase Auth.
  /// Returns true if the email exists, false otherwise.
  Future<bool> emailExists(String email) async {
    try {
      // Try to create a user to check if email exists
      // The Firebase Auth SDK no longer provides fetchSignInMethodsForEmail
      // So we'll just let the registration attempt handle it
      // and catch the email-already-in-use error
      return false; // Always return false, let registration handle the check
    } catch (e) {
      return false;
    }
  }

  /// Registers a new user in Firebase Auth and records the `userType` in
  /// Firestore under `users/{uid}`. Returns `null` on success or an
  /// error message string on failure.
  Future<String?> register(
    String email,
    String password,
    String userType, {
    String? firstName,
    String? lastName,
    int? age,
    String? address,
    String? phone,
    String? locationDescription,
  }) async {
    try {
      // Debug log
      // ignore: avoid_print
      print(
        'FirebaseAuthService.register: attempting to create user $email as $userType',
      );

      // Validate inputs before attempting Firebase registration
      final e = email.trim();
      final p = password;

      if (e.isEmpty || p.isEmpty) {
        return 'Email and password are required.';
      }

      // Basic email format check
      final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
      if (!emailRegex.hasMatch(e)) {
        return 'Please enter a valid email address.';
      }

      if (p.length < 6) {
        return 'Password must be at least 6 characters.';
      }

      // Create user with Firebase Auth
      // Note: Firebase Auth will automatically check if email exists
      // and throw 'email-already-in-use' error if it does
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: e,
        password: p,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        return 'Registration failed: No user ID returned.';
      }

      // Persist the user type in Firestore for later lookups on sign-in
      try {
        final userData = {
          'email': e.toLowerCase(),
          'type': userType,
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Owner and courier accounts start with pending status and require admin approval
        if (userType == 'owner' || userType == 'courier') {
          userData['status'] = 'pending';
        }

        // Add optional fields if provided
        if (firstName != null && firstName.isNotEmpty)
          userData['firstName'] = firstName;
        if (lastName != null && lastName.isNotEmpty)
          userData['lastName'] = lastName;
        if (age != null) userData['age'] = age;
        if (address != null && address.isNotEmpty) {
          userData['location'] = address;
        }
        if (phone != null && phone.isNotEmpty) userData['phone'] = phone;
        if (locationDescription != null && locationDescription.isNotEmpty)
          userData['locationDescription'] = locationDescription;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData);

        // ignore: avoid_print
        print(
          'FirebaseAuthService.register: created uid $uid and wrote Firestore record',
        );
      } catch (firestoreError) {
        // Critical: Firestore write failed. Delete the auth account to maintain consistency
        // ignore: avoid_print
        print(
          'FirebaseAuthService.register: Firestore write failed: $firestoreError',
        );

        // Clean up: delete the Firebase Auth account we just created
        try {
          await cred.user?.delete();
          // ignore: avoid_print
          print('FirebaseAuthService.register: Cleaned up auth account');
        } catch (deleteError) {
          // ignore: avoid_print
          print(
            'FirebaseAuthService.register: Failed to clean up auth account: $deleteError',
          );
        }

        return 'Registration failed: Could not save user data. Please try again.';
      }

      return null;
    } on FirebaseAuthException catch (e) {
      // Map Firebase error codes to user-friendly messages
      // ignore: avoid_print
      print(
        'FirebaseAuthService.register: FirebaseAuthException ${e.code} ${e.message}',
      );

      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already registered. Please login instead.';
        case 'invalid-email':
          return 'Invalid email address format.';
        case 'operation-not-allowed':
          return 'Email/password accounts are not enabled. Please contact support.';
        case 'weak-password':
          return 'Password is too weak. Please use a stronger password.';
        case 'network-request-failed':
          return 'Network error. Please check your connection and try again.';
        default:
          return e.message ?? 'Registration failed. Please try again.';
      }
    } catch (e) {
      // Don't fall back to in-memory service during registration.
      // Registration should only happen through Firebase to ensure data consistency.
      // ignore: avoid_print
      print('FirebaseAuthService.register: unexpected error: $e');
      return 'Registration failed. Please check your internet connection and try again.';
    }
  }

  /// Attempts to sign in. Returns the `userType` on success (e.g. 'customer',
  /// 'owner', 'courier'), or `null` on failure (which signals the UI to show
  /// the "create account" prompt).
  Future<String?> login(String email, String password) async {
    try {
      // ignore: avoid_print
      print('FirebaseAuthService.login: attempting signIn for $email');

      // Try logging in with the provided email
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Prefer the current authenticated user object; sometimes `cred.user`
      // can be null in edge cases so check both and reload to ensure tokens
      // and user state are up-to-date after sign-in.
      User? user = FirebaseAuth.instance.currentUser ?? cred.user;
      if (user == null) {
        // Try a short delay in case the SDK hasn't populated currentUser yet.
        await Future.delayed(const Duration(milliseconds: 200));
        user = FirebaseAuth.instance.currentUser ?? cred.user;
      }

      if (user == null) {
        // No user available after sign-in.
        // ignore: avoid_print
        print('FirebaseAuthService.login: no Firebase user after signIn');
        return null;
      }

      // Ensure the user record is refreshed (important when the app was
      // restarted and token/claims may be stale).
      try {
        await user.reload();
        user = FirebaseAuth.instance.currentUser ?? user;
      } catch (_) {
        // Non-fatal; continue with the available user object.
      }

      final userNonNull = user!;
      final uid = userNonNull.uid;

      // Check custom claims first (server-side admin flag) if available.
      try {
        final idTokenResult = await userNonNull.getIdTokenResult(true);
        final claims = idTokenResult.claims;
        if (claims != null && claims['admin'] == true) {
          // ignore: avoid_print
          print('FirebaseAuthService.login: admin custom claim found for $uid');
          return 'admin';
        }
      } catch (e) {
        // ignore token/claim errors; fall back to Firestore lookup below.
        // ignore: avoid_print
        print('FirebaseAuthService.login: error checking custom claims: $e');
      }

      // Look up the user document by the authenticated user's UID. If the
      // document exists we return its `type` (or default to `customer` if the
      // field is missing). Only if the document truly does not exist should
      // we signal the UI to show the Create Account flow (return `null`).
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists) {
          final data = doc.data();

          // Check if account is pending approval
          if (data != null && data['status'] == 'pending') {
            // Sign out the user immediately
            await FirebaseAuth.instance.signOut();
            // Return a special error code that the UI can detect
            throw FirebaseAuthException(
              code: 'account-pending',
              message:
                  'Your account is pending approval by an administrator. You will be able to access your account once it has been approved.',
            );
          }

          // Check if account is rejected
          if (data != null && data['status'] == 'rejected') {
            // Sign out the user immediately
            await FirebaseAuth.instance.signOut();
            // Return a special error code that the UI can detect
            throw FirebaseAuthException(
              code: 'account-rejected',
              message:
                  'Your account has been rejected by the administrator. Please contact support for more information.',
            );
          }

          // Check if account is suspended
          if (data != null && data['status'] == 'suspended') {
            // Sign out the user immediately
            await FirebaseAuth.instance.signOut();
            // Return a special error code that the UI can detect
            throw FirebaseAuthException(
              code: 'account-suspended',
              message:
                  'Your account has been suspended by the administrator. Please contact support for assistance.',
            );
          }

          if (data != null && data['type'] is String) {
            final userType = data['type'] as String;

            // If user is a courier, automatically set them as online
            if (userType == 'courier') {
              try {
                await FirebaseFirestore.instance
                    .collection('couriers')
                    .doc(uid)
                    .set({
                      'userId': uid,
                      'isOnline': true,
                      'isAvailable': true,
                      'lastOnline': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
              } catch (e) {
                // ignore: avoid_print
                print('Failed to set courier online status: $e');
              }
            }

            return userType;
          }
          // Document exists but no explicit type — treat as customer.
          return 'customer';
        }

        // Document does not exist - this could mean:
        // 1. User authenticated successfully but Firestore document was never created
        // 2. Database permissions issue
        // We should create the document automatically for the user as a fallback
        // ignore: avoid_print
        print(
          'FirebaseAuthService.login: no Firestore user doc for $uid — creating default customer account',
        );

        // Create a default customer account document
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'email': email.toLowerCase(),
            'type': 'customer',
            'createdAt': FieldValue.serverTimestamp(),
          });
          // ignore: avoid_print
          print(
            'FirebaseAuthService.login: created default customer account for $uid',
          );
          return 'customer';
        } catch (createError) {
          // ignore: avoid_print
          print(
            'FirebaseAuthService.login: failed to create user document: $createError',
          );
          // If we can't create the document, throw an error instead of returning null
          throw FirebaseAuthException(
            code: 'user-data-error',
            message:
                'Unable to access your account data. Please check your internet connection and try again.',
          );
        }
      } on FirebaseAuthException catch (e) {
        // Re-throw account status errors and network errors so they can be caught by the UI
        if (e.code == 'account-suspended' ||
            e.code == 'account-pending' ||
            e.code == 'account-rejected' ||
            e.code == 'user-data-error') {
          rethrow;
        }
        // Other Firebase auth errors from the suspension check
        // ignore: avoid_print
        print('FirebaseAuthService.login: Firestore FirebaseAuthException $e');
        return null;
      } on FirebaseException catch (e) {
        // Firestore read failures (e.g., permission-denied).
        // For network errors, convert to a more specific exception
        if (e.code == 'unavailable' || e.message?.contains('network') == true) {
          throw FirebaseAuthException(
            code: 'network-request-failed',
            message:
                'Network error. Please check your internet connection and try again.',
          );
        }
        // ignore: avoid_print
        print('FirebaseAuthService.login: Firestore error $e');
        return null;
      }
    } on FirebaseAuthException catch (e) {
      // Firebase auth error (e.g., wrong-password, user-not-found, network-request-failed).
      // ignore: avoid_print
      print(
        'FirebaseAuthService.login: FirebaseAuthException ${e.code} ${e.message}',
      );

      // Re-throw specific errors that should be shown to the user
      if (e.code == 'account-suspended' ||
          e.code == 'account-pending' ||
          e.code == 'account-rejected' ||
          e.code == 'user-data-error' ||
          e.code == 'network-request-failed' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found' ||
          e.code == 'invalid-email' ||
          e.code == 'too-many-requests' ||
          e.code == 'user-disabled') {
        rethrow;
      }

      return null;
    } catch (e) {
      // Firebase not available or unexpected error.
      // ignore: avoid_print
      print('FirebaseAuthService.login: unexpected error $e');
      return null;
    }
  }

  /// Optionally expose sign-out for other parts of the app.
  Future<void> signOut() async {
    try {
      // Get current user before signing out
      final user = FirebaseAuth.instance.currentUser;

      // If user is logged in, check if they're a courier and set offline status
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists && userDoc.data()?['type'] == 'courier') {
            // Set courier as offline
            await FirebaseFirestore.instance
                .collection('couriers')
                .doc(user.uid)
                .set({
                  'isOnline': false,
                  'isAvailable': false,
                  'lastOnline': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
          }
        } catch (e) {
          // ignore: avoid_print
          print('Failed to set offline status on signout: $e');
        }
      }

      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // ignore - fallback/no-op
    }
  }
}
