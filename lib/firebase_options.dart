import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return ios;
    }
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAl5kiM0tqQ1jyLcR1N72Lo2VQgLhb-KoQ',
    appId: '1:439704193376:android:389cfa9d7a49938fe27605',
    messagingSenderId: '439704193376',
    projectId: 'parkgozcuproje',
    storageBucket: 'parkgozcuproje.firebasestorage.app',
    androidClientId: 'REPLACE_WITH_ANDROID_CLIENT_ID',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBSDRHkWFilEozhyMV8n6N5Ewv8Nw9RYPg',
    appId: '1:439704193376:ios:8fcf550aec875a4ee27605',
    messagingSenderId: '439704193376',
    projectId: 'parkgozcuproje',
    storageBucket: 'parkgozcuproje.firebasestorage.app',
    iosBundleId: 'com.ibrahim.parkgozcu',
    iosClientId:
        '439704193376-bl4sc61qksjh084ikp7u3rjdvta1d0la.apps.googleusercontent.com',
  );
}
