// Generated Firebase options for this project.
//
// This file was created manually by the assistant because `flutterfire configure`
// exited with an error in this environment. It contains the Android and Web
// FirebaseOptions for the `daho-dev` project. If you run `flutterfire configure`
// later it may overwrite this file with a more complete variant.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // Fallback for non-web platforms — we only provide Android here.
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCMpQ0aBJRZ8heyyXPwUJJUkIdZw5gXPNI',
    appId: '1:267862940767:android:f2d23c6d50a613646c4fea',
    messagingSenderId: '267862940767',
    projectId: 'daho-dev',
    storageBucket: 'daho-dev.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAlQi1EhaomzCg_Xd6qenIkzPiAT23hz-M',
    appId: '1:267862940767:web:e3de293d5b38f1226c4fea',
    messagingSenderId: '267862940767',
    projectId: 'daho-dev',
    authDomain: 'daho-dev.firebaseapp.com',
    storageBucket: 'daho-dev.firebasestorage.app',
    measurementId: 'G-Q72PWF5HW8',
  );
}
