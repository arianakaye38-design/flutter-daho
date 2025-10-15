import 'package:flutter/material.dart';
import 'owner_account.dart';

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

    // ✅ Navigate to corresponding dashboard
    setState(() => error = '');
    if (userType == 'owner') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OwnerDashboard()),
      );
    } else if (userType == 'customer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CustomerAccount()),
      );
    } else if (userType == 'courier') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CourierDashboard()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF222b36),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/DAHO LOGO.jpg',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              const Text('Daho!',
                  style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA2AD51),
                      letterSpacing: 2)),
              const SizedBox(height: 8),
              const Text('Login',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: userTypes.map((type) {
                  final isSelected = userType == type['value'];
                  final iconColor =
                      isSelected ? Colors.white : const Color(0xFF1976d2);
                  return GestureDetector(
                    onTap: () =>
                        setState(() => userType = type['value'] as String),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1976d2)
                            : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isSelected
                                ? const Color(0xFF070707)
                                : Colors.grey),
                      ),
                      child: Column(
                        children: [
                          Icon(type['icon'] as IconData,
                              color: iconColor, size: 25),
                          const SizedBox(height: 4),
                          Text(type['label'] as String,
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.w500))
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error,
                      style: const TextStyle(color: Colors.red, fontSize: 14)),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: handleLogin,
                style: ElevatedButton.styleFrom(
                  minimumSize:
                      Size(MediaQuery.of(context).size.width * 0.5, 48),
                  backgroundColor: const Color(0xFF1976d2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                child: const Text('Log In',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1)),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/Sign-up');
                },
                style: OutlinedButton.styleFrom(
                  minimumSize:
                      Size(MediaQuery.of(context).size.width * 0.5, 48),
                  side: const BorderSide(color: Color(0xFF1976d2)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Colors.white,
                  elevation: 1,
                ),
                child: const Text('Sign Up',
                    style: TextStyle(
                        color: Color(0xFF1976d2),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Example placeholder screens
class CustomerAccount extends StatelessWidget {
  const CustomerAccount({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: const Center(child: Text('Customer Account')),
      );
}

class CourierDashboard extends StatelessWidget {
  const CourierDashboard({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: const Center(child: Text('Courier Dashboard')),
      );
}
