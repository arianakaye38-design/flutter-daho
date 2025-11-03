import 'package:flutter/material.dart';
import 'sign_in.dart';
import 'sign_up.dart';

class AuthChoice extends StatelessWidget {
  const AuthChoice({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Welcome to Daho!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(220, 56),
                  backgroundColor: Colors.green,
                ),
                child: const Text(
                  'Create an account',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(220, 56),
                ),
                child: const Text(
                  'I already have an account',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
