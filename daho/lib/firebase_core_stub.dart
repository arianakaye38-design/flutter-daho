// Minimal shim to allow running the app without the real firebase_core
// package. When you re-enable Firebase packages and run `flutterfire
// configure`, you can remove this file.

class Firebase {
  static Future<void> initializeApp({dynamic options}) async {
    // no-op shim
    return;
  }
}
