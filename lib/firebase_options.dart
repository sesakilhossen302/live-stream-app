import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: (dotenv.isInitialized ? dotenv.env['FIREBASE_ANDROID_API_KEY'] : null) ??
            'AIzaSyDummyKeyForLiveStreamApp123456789',
        appId: (dotenv.isInitialized ? dotenv.env['FIREBASE_ANDROID_APP_ID'] : null) ??
            '1:123456789012:android:abcdef1234567890',
        messagingSenderId: (dotenv.isInitialized ? dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] : null) ??
            '123456789012',
        projectId: (dotenv.isInitialized ? dotenv.env['FIREBASE_PROJECT_ID'] : null) ??
            'culturecards-live-stream',
        storageBucket: (dotenv.isInitialized ? dotenv.env['FIREBASE_STORAGE_BUCKET'] : null) ??
            'culturecards-live-stream.appspot.com',
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: (dotenv.isInitialized ? dotenv.env['FIREBASE_IOS_API_KEY'] : null) ??
            'AIzaSyDummyKeyForLiveStreamApp123456789',
        appId: (dotenv.isInitialized ? dotenv.env['FIREBASE_IOS_APP_ID'] : null) ??
            '1:123456789012:ios:abcdef1234567890',
        messagingSenderId: (dotenv.isInitialized ? dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] : null) ??
            '123456789012',
        projectId: (dotenv.isInitialized ? dotenv.env['FIREBASE_PROJECT_ID'] : null) ??
            'culturecards-live-stream',
        storageBucket: (dotenv.isInitialized ? dotenv.env['FIREBASE_STORAGE_BUCKET'] : null) ??
            'culturecards-live-stream.appspot.com',
        iosBundleId: 'com.culturecards.app',
      );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDummyKeyForLiveStreamApp123456789',
    appId: '1:123456789012:web:abcdef1234567890',
    messagingSenderId: '123456789012',
    projectId: 'culturecards-live-stream',
    authDomain: 'culturecards-live-stream.firebaseapp.com',
    storageBucket: 'culturecards-live-stream.appspot.com',
  );
}
