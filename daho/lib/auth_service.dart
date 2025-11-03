class AuthService {
  AuthService._privateConstructor() {
    // ensure there's a demo user available for testing
    seedDemoAccount();
  }

  static final AuthService instance = AuthService._privateConstructor();

  // Simple in-memory user store: email -> {password, type}
  final Map<String, Map<String, String>> _users = {};

  /// Registers a user. Returns null on success, or an error message.
  String? register(String email, String password, String userType) {
    final e = email.trim().toLowerCase();
    final p = password;

    if (e.isEmpty || p.isEmpty) return 'Email and password are required.';

    // basic email format check
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    if (!emailRegex.hasMatch(e)) return 'Please enter a valid email address.';

    if (_users.containsKey(e)) return 'Email already registered.';
    if (p.length < 8) return 'Password must be at least 8 characters.';

    _users[e] = {'password': p, 'type': userType};
    return null;
  }

  /// Attempts to log in. Returns the user type on success, or null on failure.
  String? login(String email, String password) {
    final e = email.trim().toLowerCase();
    final p = password;

    final user = _users[e];
    if (user == null) return null;
    if (user['password'] != p) return null;
    return user['type'];
  }

  // Helper for tests / debug: add a default account
  void seedDemoAccount() {
    _users.putIfAbsent(
      'demo@daho.app',
      () => {'password': 'demopassword', 'type': 'customer'},
    );
  }
}
