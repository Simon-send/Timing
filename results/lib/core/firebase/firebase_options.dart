import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Default Firebase configuration for the Results app.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase is only configured for web in this project right now.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAynKuF85SLcE6yZyUCdRHn-PrrPgtMQf8',
    appId: '1:1009635085387:web:8a1513681059657ac1d1ce',
    messagingSenderId: '1009635085387',
    projectId: 'time-plotting',
    authDomain: 'time-plotting.firebaseapp.com',
    storageBucket: 'time-plotting.firebasestorage.app',
    measurementId: 'G-P7C9QL9EXS',
  );
}
