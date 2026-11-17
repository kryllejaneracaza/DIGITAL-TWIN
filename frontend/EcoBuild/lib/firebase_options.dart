import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD31L8tgi4qTfNkT37vydldXho5p-z8ks0',
    appId: '1:464331902645:web:e11c6a480a94475fe878fc',
    messagingSenderId: '464331902645',
    projectId: 'ecobuild-3469b',
    authDomain: 'ecobuild-3469b.firebaseapp.com',
    storageBucket: 'ecobuild-3469b.firebasestorage.app',
    measurementId: 'G-LBB7ZPRBTN',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCCw53CMFwHj7DoFjJe8a-Ct_yXjp_6leM',
    appId: '1:464331902645:android:e20ec419ad8a5496e878fc',
    messagingSenderId: '464331902645',
    projectId: 'ecobuild-3469b',
    storageBucket: 'ecobuild-3469b.firebasestorage.app',
  );
}
