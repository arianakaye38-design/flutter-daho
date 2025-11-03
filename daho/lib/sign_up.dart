import 'package:flutter/material.dart';
import 'services/firebase_auth_service.dart';
import 'log_in.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String userType = 'customer';
  String error = '';

  void _handleSignUp() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    final err = await FirebaseAuthService.instance.register(
      email,
      password,
      userType,
    );
    if (err != null) {
      setState(() => error = err);
      return;
    }

    // On success, navigate to login (user should now log in)
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: userType,
              items: const [
                DropdownMenuItem(value: 'customer', child: Text('Customer')),
                DropdownMenuItem(
                  value: 'owner',
                  child: Text('Pasalubong Owner'),
                ),
                DropdownMenuItem(
                  value: 'courier',
                  child: Text('Local Courier'),
                ),
              ],
              onChanged: (v) => setState(() => userType = v ?? 'customer'),
            ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _handleSignUp,
              child: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
