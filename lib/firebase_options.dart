import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions? get currentPlatform {
    if (!kIsWeb) return null;
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCeG9Ht-X4DUb0uRshyWu-KDzGvh4mlT6o', 
    appId: '1:100334214783:web:24ca2a8b4c3b0f6912e94a',
    messagingSenderId: '100334214783',
    projectId: 'instagram-local',
    authDomain: 'instagram-local.firebaseapp.com',
    storageBucket: 'instagram-local.firebasestorage.app',
  );
}
