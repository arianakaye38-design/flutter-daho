import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Quick fix to ensure current user has type='customer' in Firestore
class FixCustomerTypeScreen extends StatefulWidget {
  const FixCustomerTypeScreen({super.key});

  @override
  State<FixCustomerTypeScreen> createState() => _FixCustomerTypeScreenState();
}

class _FixCustomerTypeScreenState extends State<FixCustomerTypeScreen> {
  String _status = 'Checking user data...';
  bool _isFixed = false;

  @override
  void initState() {
    super.initState();
    _checkAndFixUserType();
  }

  Future<void> _checkAndFixUserType() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = 'Error: No user is logged in';
        });
        return;
      }

      final userId = user.uid;
      final email = user.email ?? 'N/A';

      setState(() {
        _status = 'Checking user: $email\nUID: $userId';
      });

      await Future.delayed(const Duration(seconds: 1));

      // Get current user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        // User document doesn't exist - create it
        setState(() {
          _status = 'User document missing. Creating new document...';
        });

        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'email': email,
          'type': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _status = 'Success! Created user document with type="customer"';
          _isFixed = true;
        });
      } else {
        // User document exists - check if type field is set
        final userData = userDoc.data()!;
        final currentType = userData['type'];

        if (currentType == null) {
          // Type field is missing - add it
          setState(() {
            _status = 'Type field missing. Adding type="customer"...';
          });

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({'type': 'customer'});

          setState(() {
            _status = 'Success! Added type="customer" to your account';
            _isFixed = true;
          });
        } else {
          // Type field exists
          setState(() {
            _status =
                'Your account type is already set to: "$currentType"\n\nNo changes needed.';
            _isFixed = currentType == 'customer';
          });
        }
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix Customer Account'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isFixed ? Icons.check_circle : Icons.info_outline,
                size: 80,
                color: _isFixed ? Colors.green : Colors.blue,
              ),
              const SizedBox(height: 24),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              if (_isFixed)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Your account is fixed! You can now place orders.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 18)),
                ),
              if (!_isFixed)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Go Back'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
