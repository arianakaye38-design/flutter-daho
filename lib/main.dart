import 'package:flutter/material.dart';
import 'log_in.dart';

// Generated Firebase options (created by `flutterfire configure`). The
// generated file exports `DefaultFirebaseOptions.currentPlatform` for each
// platform. We keep the call guarded so the app continues to run in local
// mode if the file is still the stub.
import 'firebase_options.dart' as firebase_options;

// Use the real firebase_core package. Initialization is guarded below so the
// app will still run if `DefaultFirebaseOptions.currentPlatform` is null.
import 'package:firebase_core/firebase_core.dart' as firebase_core;

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DAHO',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Guarded Firebase initialization: attempt to read generated options. If
  // not present, continue in local/in-memory mode using the existing stubs.
  try {
    final options = firebase_options.DefaultFirebaseOptions.currentPlatform;
    // Initialize Firebase with the generated options. If the generated file
    // is later removed or returns a different type this call will throw and
    // be caught by the surrounding try/catch.
    await firebase_core.Firebase.initializeApp(options: options);
    debugPrint('Firebase initialized');
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  runApp(const MainApp());
}
