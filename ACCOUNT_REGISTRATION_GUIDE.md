# Account Registration Error Guide

## Understanding the "Email Already in Use" Error

### What's Happening?

The error message you're seeing:
```
The email address is already in use by another account.
FirebaseAuthException email-already-in-use
```

This means the email **actually exists** in Firebase Authentication. This is **not a bug** - Firebase is correctly detecting an existing account.

---

## Why This Happens

### Scenario 1: Previous Test Account
During development/testing, you may have created an account with this email. Even if you:
- Deleted the user document from Firestore
- Cleared app data
- Reinstalled the app

**The Firebase Authentication account still exists!**

Firebase Authentication and Firestore are **separate services**:
- **Firebase Authentication** = Login credentials (email/password)
- **Firestore** = User data storage (profile, type, etc.)

### Scenario 2: Incomplete Registration
An account was created but the process failed before completing, leaving an orphaned auth account.

---

## Solutions

### Option 1: Use a Different Email (Quick Fix)
Try registering with a different email address that hasn't been used before.

### Option 2: Login with the Existing Account
If you know the password, click "Go to Login" when the dialog appears.

### Option 3: Delete the Firebase Auth Account (Testing Only)

#### Via Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication** → **Users**
4. Find the email in the list
5. Click the **⋮** menu → **Delete account**
6. Confirm deletion
7. Try registering again

#### Via Firebase Admin SDK (Backend):
```javascript
// backend/functions/deleteUser.js
const admin = require('firebase-admin');

exports.deleteUserByEmail = functions.https.onCall(async (data, context) => {
  // Only allow admins to delete users
  if (context.auth.token.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Not authorized');
  }
  
  const email = data.email;
  const userRecord = await admin.auth().getUserByEmail(email);
  await admin.auth().deleteUser(userRecord.uid);
  
  return { success: true, message: `Deleted user: ${email}` };
});
```

### Option 4: Password Reset Flow
If you forgot the password of an existing account:

1. Add password reset functionality to login screen:
```dart
// lib/log_in.dart
Future<void> _resetPassword(String email) async {
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Password reset email sent to $email')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}
```

---

## What I Changed in the Code

### 1. Pre-Registration Email Check
Added `emailExists()` method that checks if an email is registered **before** attempting to create the account:

```dart
// lib/services/firebase_auth_service.dart
Future<bool> emailExists(String email) async {
  try {
    final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email.trim());
    return methods.isNotEmpty;
  } catch (e) {
    return false;
  }
}
```

This provides a clearer error message upfront.

### 2. Account Exists Dialog
When registration fails due to existing email, a dialog appears offering to:
- Cancel (try different email)
- Go to Login (use existing account)

```dart
// lib/sign_up.dart
void _showAccountExistsDialog(String email) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Account Already Exists'),
      content: Text('An account with "$email" already exists...'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
          child: const Text('Go to Login'),
        ),
      ],
    ),
  );
}
```

### 3. Better Error Messages
All Firebase error codes now map to user-friendly messages:
- `email-already-in-use` → "This email is already registered. Please login instead."
- `invalid-email` → "Invalid email address format."
- `weak-password` → "Password is too weak. Please use a stronger password."
- `network-request-failed` → "Network error. Please check your connection."

---

## Debugging: Check What's in Firebase

### Via Firebase Console
1. Go to **Authentication** → **Users**
2. Look for the email you're trying to register
3. If it exists, you'll see:
   - UID
   - Creation date
   - Last sign-in date
   - Provider (Email/Password)

### Via Flutter Debug Output
The app now logs detailed information:
```
I/flutter: FirebaseAuthService.register: attempting to create user test@example.com as customer
I/flutter: FirebaseAuthService.register: email test@example.com already exists in Firebase Auth
I/flutter: FirebaseAuthService.register: FirebaseAuthException email-already-in-use
```

---

## Testing Strategy

For development/testing, use one of these approaches:

### Approach 1: Disposable Email Addresses
Use temporary email services:
- `test+1@example.com`
- `test+2@example.com`
- `test+3@example.com`

Gmail and many services treat these as unique emails.

### Approach 2: Delete Test Accounts After Each Test
Create a cleanup script:
```javascript
// backend/functions/cleanupTestUsers.js
exports.deleteAllTestUsers = functions.https.onCall(async (data, context) => {
  const listUsersResult = await admin.auth().listUsers();
  const testUsers = listUsersResult.users.filter(u => 
    u.email.includes('+test') || u.email.startsWith('test')
  );
  
  for (const user of testUsers) {
    await admin.auth().deleteUser(user.uid);
    await admin.firestore().collection('users').doc(user.uid).delete();
  }
  
  return { deleted: testUsers.length };
});
```

### Approach 3: Use Firebase Emulator
For local testing without affecting production:
```bash
firebase emulators:start --only auth,firestore
```

Update Flutter to connect to emulator:
```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Connect to emulators (debug mode only)
  if (kDebugMode) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }
  
  runApp(const MyApp());
}
```

---

## Production Considerations

### Email Verification
Add email verification after registration:
```dart
final user = cred.user;
if (user != null && !user.emailVerified) {
  await user.sendEmailVerification();
}
```

### Rate Limiting
Prevent spam registration attempts using Firebase App Check or Cloud Functions.

### Duplicate Detection
The current implementation prevents duplicate emails by design (Firebase feature).

---

## Common Questions

**Q: Why doesn't deleting from Firestore delete the auth account?**  
A: Firebase Authentication and Firestore are separate. You must delete from both.

**Q: Can I reuse an email after deleting the account?**  
A: Yes, but only after deleting from Firebase Authentication (not just Firestore).

**Q: What if I want to update user type instead of creating new account?**  
A: You'd need to:
1. Login with existing credentials
2. Update the Firestore `users/{uid}` document
3. Update custom claims via Cloud Functions

**Q: How do I know if it's checking Firebase vs. local memory?**  
A: Look at debug logs:
- `FirebaseAuthService.register: attempting to create user...` = Using Firebase
- `FirebaseAuthService.register: email X already exists in Firebase Auth` = Pre-check found it
- `FirebaseAuthException email-already-in-use` = Firebase confirmed it exists

---

## Next Steps

1. **Check Firebase Console** to see if the email exists
2. **Delete the test account** if it's just for testing
3. **Try registering again** with a fresh email
4. **Or use "Go to Login"** if it's a real account

The app now provides better feedback and guidance when this happens!
