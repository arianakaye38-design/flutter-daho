import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing user account changes like email and password updates
class UserAccountService {
  UserAccountService._private();
  static final UserAccountService instance = UserAccountService._private();

  /// Updates the user's email in both Firebase Auth and Firestore
  /// This migrates the account by creating a new Firebase Auth account
  /// Returns null on success or an error message on failure
  Future<String?> updateEmail(String newEmail, String currentPassword) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return 'No user is currently signed in.';
      }

      // Validate email format
      final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
      if (!emailRegex.hasMatch(newEmail)) {
        return 'Please enter a valid email address.';
      }

      // Get the user's current email
      final currentEmail = user.email;
      if (currentEmail == null) {
        return 'Unable to retrieve current email.';
      }

      if (currentEmail.toLowerCase() == newEmail.toLowerCase()) {
        return 'New email is the same as current email.';
      }

      // Re-authenticate the user before making changes
      final credential = EmailAuthProvider.credential(
        email: currentEmail,
        password: currentPassword,
      );

      try {
        await user.reauthenticateWithCredential(credential);
      } catch (e) {
        return 'Current password is incorrect. Please try again.';
      }

      final oldUserId = user.uid;
      final oldEmail = currentEmail;

      // Get all user data from Firestore BEFORE creating new account
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(oldUserId)
          .get();

      if (!userDoc.exists) {
        return 'User data not found in database.';
      }

      final userData = Map<String, dynamic>.from(userDoc.data()!);

      // Get references that need to be updated
      List<DocumentReference> courierRefsToUpdate = [];
      List<DocumentReference> centerRefsToUpdate = [];

      if (userData['type'] == 'courier') {
        final courierDocs = await FirebaseFirestore.instance
            .collection('couriers')
            .where('userId', isEqualTo: oldUserId)
            .get();
        courierRefsToUpdate = courierDocs.docs
            .map((doc) => doc.reference)
            .toList();
      }

      if (userData['type'] == 'owner') {
        final centerDocs = await FirebaseFirestore.instance
            .collection('pasalubong_centers')
            .where('ownerId', isEqualTo: oldUserId)
            .get();
        centerRefsToUpdate = centerDocs.docs
            .map((doc) => doc.reference)
            .toList();
      }

      // Check if new email is already in use
      final existingUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: newEmail.toLowerCase())
          .limit(1)
          .get();

      if (existingUsers.docs.isNotEmpty) {
        return 'This email is already in use by another account.';
      }

      // Delete old user document FIRST (while we're still the old user)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(oldUserId)
          .delete();

      // Sign out
      await FirebaseAuth.instance.signOut();

      // Create new Firebase Auth account (automatically signs in as new user)
      UserCredential newUserCred;
      try {
        newUserCred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: newEmail,
              password: currentPassword,
            );
      } on FirebaseAuthException catch (e) {
        // Failed to create new account - restore old user data
        await FirebaseFirestore.instance
            .collection('users')
            .doc(oldUserId)
            .set(userData);

        // Sign back in as old user
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: oldEmail,
            password: currentPassword,
          );
        } catch (_) {}

        if (e.code == 'email-already-in-use') {
          return 'This email is already in use by another account.';
        }
        return e.message ?? 'Failed to create new account with new email.';
      }

      final newUserId = newUserCred.user?.uid;
      if (newUserId == null) {
        // Failed - restore old user data
        await FirebaseFirestore.instance
            .collection('users')
            .doc(oldUserId)
            .set(userData);

        // Sign back in as old user
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: oldEmail,
            password: currentPassword,
          );
        } catch (_) {}
        return 'Failed to create new account.';
      }

      // Now we're authenticated as NEW user - create our Firestore document
      // Prepare clean userData - remove system-generated fields that can't be set by clients
      final cleanUserData = <String, dynamic>{
        'email': newEmail.toLowerCase(),
        'type': userData['type'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Copy optional user fields if they exist
      if (userData.containsKey('name') && userData['name'] != null) {
        cleanUserData['name'] = userData['name'];
      }
      if (userData.containsKey('age') && userData['age'] != null) {
        cleanUserData['age'] = userData['age'];
      }
      if (userData.containsKey('address') && userData['address'] != null) {
        cleanUserData['address'] = userData['address'];
      }
      if (userData.containsKey('phone') && userData['phone'] != null) {
        cleanUserData['phone'] = userData['phone'];
      }
      if (userData.containsKey('status') && userData['status'] != null) {
        cleanUserData['status'] = userData['status'];
      }

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(newUserId)
            .set(cleanUserData);
      } catch (e) {
        // Failed to create new user doc - restore old user
        await FirebaseFirestore.instance
            .collection('users')
            .doc(oldUserId)
            .set(userData);

        // Delete the new auth account
        try {
          await newUserCred.user?.delete();
        } catch (_) {}

        // Sign back in as old user
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: oldEmail,
            password: currentPassword,
          );
        } catch (_) {}

        return 'Failed to create user profile. Please try again.';
      }

      // Update collection references to point to new UID
      for (var courierRef in courierRefsToUpdate) {
        try {
          await courierRef.update({'userId': newUserId});
        } catch (e) {
          // ignore: avoid_print
          print('Warning: Failed to update courier reference: $e');
        }
      }

      for (var centerRef in centerRefsToUpdate) {
        try {
          await centerRef.update({'ownerId': newUserId, 'userId': newUserId});
        } catch (e) {
          // ignore: avoid_print
          print('Warning: Failed to update center reference: $e');
        }
      }

      // Try to delete old Firebase Auth account (sign in and delete)
      try {
        await FirebaseAuth.instance.signOut();
        final oldUserCred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: oldEmail,
              password: currentPassword,
            );
        await oldUserCred.user?.delete();
        // ignore: avoid_print
        print(
          'UserAccountService: Successfully deleted old Firebase Auth account',
        );

        // Sign back in as new user
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: newEmail,
          password: currentPassword,
        );
      } catch (e) {
        // If deletion fails, at least ensure we're signed in as new user
        // ignore: avoid_print
        print('Warning: Could not delete old Firebase Auth account: $e');

        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: newEmail,
            password: currentPassword,
          );
        } catch (signInError) {
          // ignore: avoid_print
          print('Error signing in with new account: $signInError');
        }
      }

      // ignore: avoid_print
      print(
        'UserAccountService: Email migrated successfully to $newEmail with uid $newUserId',
      );
      return null;
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('UserAccountService: FirebaseAuthException ${e.code} ${e.message}');

      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already in use by another account.';
        case 'invalid-email':
          return 'Invalid email address format.';
        case 'requires-recent-login':
          return 'Please log out and log back in before changing your email.';
        default:
          return e.message ?? 'Failed to update email.';
      }
    } catch (e) {
      // ignore: avoid_print
      print('UserAccountService: Error updating email: $e');
      return 'Failed to update email. Please try again.';
    }
  }

  /// Updates the user's password in Firebase Auth
  /// Returns null on success or an error message on failure
  Future<String?> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return 'No user is currently signed in.';
      }

      // Validate new password
      if (newPassword.length < 6) {
        return 'Password must be at least 6 characters long.';
      }

      if (currentPassword == newPassword) {
        return 'New password must be different from current password.';
      }

      // Get the user's current email
      final currentEmail = user.email;
      if (currentEmail == null) {
        return 'Unable to retrieve current email.';
      }

      // Re-authenticate the user before changing password (required by Firebase)
      final credential = EmailAuthProvider.credential(
        email: currentEmail,
        password: currentPassword,
      );

      try {
        await user.reauthenticateWithCredential(credential);
      } catch (e) {
        return 'Current password is incorrect. Please try again.';
      }

      // Update password in Firebase Auth
      await user.updatePassword(newPassword);

      // ignore: avoid_print
      print('UserAccountService: Password updated successfully');
      return null;
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('UserAccountService: FirebaseAuthException ${e.code} ${e.message}');

      switch (e.code) {
        case 'weak-password':
          return 'Password is too weak. Please use a stronger password.';
        case 'requires-recent-login':
          return 'Please log out and log back in before changing your password.';
        default:
          return e.message ?? 'Failed to update password.';
      }
    } catch (e) {
      // ignore: avoid_print
      print('UserAccountService: Error updating password: $e');
      return 'Failed to update password. Please try again.';
    }
  }

  /// Updates both email and password by migrating the account
  /// Returns null on success or an error message on failure
  Future<String?> updateEmailAndPassword(
    String newEmail,
    String currentPassword,
    String newPassword,
  ) async {
    // First update email (which migrates the account)
    final emailError = await updateEmail(newEmail, currentPassword);
    if (emailError != null) {
      return emailError;
    }

    // Then update password on the new account
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return 'Account migration succeeded but password update failed. Please login with new email and old password, then change password.';
      }

      await user.updatePassword(newPassword);

      // ignore: avoid_print
      print(
        'UserAccountService: Email and password updated successfully to $newEmail',
      );
      return null;
    } catch (e) {
      return 'Email updated successfully but password update failed: ${e.toString()}. Please login with new email and old password.';
    }
  }
}
