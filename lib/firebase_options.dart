import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ios;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    // Cấu hình này dùng chung project để chạy Web cục bộ. Trước khi phát hành,
    // nên đăng ký một Web app riêng và tạo lại file bằng FlutterFire CLI.
    apiKey: 'AIzaSyD4sIKPKhpP880m9Ovd9AZl6rprNKCtV2Q',
    appId: '1:703561306301:android:99cc3184c4659d6e90e7d4',
    messagingSenderId: '703561306301',
    projectId: 'commit-book',
    authDomain: 'commit-book.firebaseapp.com',
    databaseURL:
        'https://commit-book-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'commit-book.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD4sIKPKhpP880m9Ovd9AZl6rprNKCtV2Q',
    appId: '1:703561306301:android:99cc3184c4659d6e90e7d4',
    messagingSenderId: '703561306301',
    projectId: 'commit-book',
    storageBucket: 'commit-book.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD6-GyAQw3gCiCVnBxD5_8mCgB42KuHyIs',
    appId: '1:703561306301:ios:ed1b1a353994fe5390e7d4',
    messagingSenderId: '703561306301',
    projectId: 'commit-book',
    databaseURL:
        'https://commit-book-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'commit-book.firebasestorage.app',
    iosBundleId: 'com.example.commicbook',
  );
}
