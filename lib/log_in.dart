import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'owner_account.dart';
import 'customer_account.dart';
import 'courier_account.dart';
import 'features/admin/index.dart' deferred as admin_feature;
import 'services/firebase_auth_service.dart';
import 'sign_up.dart';

const userTypes = [
  {'label': 'Customer', 'value': 'customer', 'icon': Icons.person},
  {'label': 'Pasalubong Owner', 'value': 'owner', 'icon': Icons.store},
  {'label': 'Local Courier', 'value': 'courier', 'icon': Icons.pedal_bike},
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String userType = userTypes[0]['value'] as String;
  String error = '';
  bool _obscurePassword = true;

  void handleLogin() {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => error = 'Please enter email and password.');
      return;
    }
    if (password.length < 8) {
      setState(() => error = 'Password must be at least 8 characters.');
      return;
    }

    // Attempt login via Firebase auth service
    FirebaseAuthService.instance
        .login(email, password)
        .then((userTypeRes) {
          if (!mounted) return;

          if (userTypeRes == null) {
            // Show explicit, styled dialog telling user to create an account
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF2B3036),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 10),
                    Text(
                      'Account required',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'YOU NEED TO CREATE AN ACCOUNT TO LOGIN.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actionsPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976d2),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SignUpScreen(initialUserType: userType),
                        ),
                      );
                    },
                    child: const Text(
                      'Create Account',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
            return;
          }

          setState(() => error = '');
          if (userTypeRes == 'owner') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OwnerDashboard()),
            );
          } else if (userTypeRes == 'admin') {
            // Lazy-load the admin feature module before navigating. Use async/await
            // and check `mounted` to avoid using BuildContext across an async gap.
            () async {
              await admin_feature.loadLibrary();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => admin_feature.AdminDashboard(),
                ),
              );
            }();
          } else if (userTypeRes == 'courier') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CourierDashboard()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CustomerAccount()),
            );
          }
        })
        .catchError((error) async {
          if (!mounted) return;

          // Check for account status errors
          if (error is FirebaseAuthException) {
            if (error.code == 'account-pending') {
              // Show pending approval dialog
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF2B3036),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.pending, color: Colors.orange),
                      SizedBox(width: 10),
                      Text(
                        'Account Pending',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    error.message ??
                        'Your account is pending approval by an administrator.',
                    style: const TextStyle(color: Colors.white),
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976d2),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'OK',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
              return;
            } else if (error.code == 'account-rejected') {
              // Show rejected account dialog
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF2B3036),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red),
                      SizedBox(width: 10),
                      Text(
                        'Account Rejected',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    error.message ??
                        'Your account has been rejected by the administrator.',
                    style: const TextStyle(color: Colors.white),
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976d2),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'OK',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
              return;
            } else if (error.code == 'account-suspended') {
              // Fetch admin contact info from Firebase
              String adminEmail = 'admin@daho.com';
              String adminPhone = '+1 (555) 123-4567';

              try {
                // Try to get admin contact from users collection where type = 'admin'
                final adminSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .where('type', isEqualTo: 'admin')
                    .limit(1)
                    .get();

                if (adminSnapshot.docs.isNotEmpty) {
                  final adminData = adminSnapshot.docs.first.data();
                  adminEmail = adminData['email'] ?? adminEmail;
                  adminPhone =
                      adminData['phoneNumber'] ??
                      adminData['phone'] ??
                      adminData['contactNumber'] ??
                      adminPhone;
                }
              } catch (e) {
                // Use default values if fetch fails
                debugPrint('Error fetching admin contact: $e');
              }

              if (!mounted) return;

              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF2B3036),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.block, color: Colors.red),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Account Suspended',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your account has been suspended by the administrator.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Please contact the administrator for assistance:',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '📧 ',
                              style: TextStyle(color: Colors.white),
                            ),
                            Expanded(
                              child: Text(
                                'Email: $adminEmail',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '📞 ',
                              style: TextStyle(color: Colors.white),
                            ),
                            Expanded(
                              child: Text(
                                'Phone: $adminPhone',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'OK',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              );
              return;
            } else if (error.code == 'user-data-error') {
              // Show user data access error dialog
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF2B3036),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.orange),
                      SizedBox(width: 10),
                      Text(
                        'Connection Error',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    error.message ??
                        'Unable to access your account data. Please check your internet connection and try again.',
                    style: const TextStyle(color: Colors.white),
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976d2),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'OK',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
              return;
            } else if (error.code == 'wrong-password') {
              setState(() => error = 'Incorrect password. Please try again.');
              return;
            } else if (error.code == 'user-not-found') {
              setState(
                () => error =
                    'No account found with this email. Please sign up first.',
              );
              return;
            } else if (error.code == 'invalid-email') {
              setState(() => error = 'Invalid email address format.');
              return;
            } else if (error.code == 'network-request-failed') {
              setState(
                () => error =
                    'Network error. Please check your internet connection.',
              );
              return;
            } else if (error.code == 'too-many-requests') {
              setState(
                () => error =
                    'Too many failed login attempts. Please try again later.',
              );
              return;
            } else if (error.code == 'user-disabled') {
              setState(
                () => error =
                    'This account has been disabled. Please contact support.',
              );
              return;
            }
          }

          // Other errors - show the actual error message
          String errorMessage = 'Login failed. ';
          if (error is FirebaseAuthException && error.message != null) {
            errorMessage += error.message!;
          } else {
            errorMessage += error.toString();
          }
          setState(() => error = errorMessage);
        });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;

    // Dynamic sizing based on screen dimensions
    final logoSize = isSmallScreen ? 80.0 : (isMediumScreen ? 100.0 : 120.0);
    final horizontalPadding = screenWidth * 0.06;
    final maxWidth = screenWidth > 600 ? 500.0 : screenWidth;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/DAHO LOGO.jpg',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: isSmallScreen ? 40 : 60),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.black54),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  TextField(
                    controller: passwordController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.black54),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black54,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                  ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(height: isSmallScreen ? 32 : 48),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: handleLogin,
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(
                          double.infinity,
                          isSmallScreen ? 44 : 48,
                        ),
                        side: const BorderSide(color: Color(0xFF1976d2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: const Color(0xFF1976d2),
                        elevation: 2,
                      ),
                      child: Text(
                        'Log In',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 16 : 18,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Text(
                    'or',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SignUpScreen(initialUserType: userType),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(
                          double.infinity,
                          isSmallScreen ? 44 : 48,
                        ),
                        side: const BorderSide(color: Color(0xFF1976d2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: Colors.white,
                        elevation: 1,
                      ),
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          color: const Color(0xFF1976d2),
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 16 : 18,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Use the shared SignUpScreen from `sign_up.dart` to avoid duplicate
// implementations and keep the behavior consistent across entry points.

// Example placeholder screens
// The actual `CustomerAccount` and `CourierDashboard` widgets are implemented
// in their respective files (`customer_account.dart` and `courier_account.dart`).
// We import those files above so navigation below will use the full-featured
// implementations instead of placeholder stubs.
