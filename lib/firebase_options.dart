import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyAl5kiM0tqQ1jyLcR1N72Lo2VQgLhb-KoQ',
      appId: '1:439704193376:android:389cfa9d7a49938fe27605',
      messagingSenderId: '439704193376',
      projectId: 'parkgozcuproje',
      storageBucket: 'parkgozcuproje.firebasestorage.app',
      iosBundleId: 'com.ibrahim.parkgozcu',
      androidClientId: 'REPLACE_WITH_ANDROID_CLIENT_ID',
      iosClientId: 'REPLACE_WITH_IOS_CLIENT_ID',
    );
  }
}
