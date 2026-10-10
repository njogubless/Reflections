import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Debug-only: `--dart-define=USE_FIREBASE_EMULATORS=true` runs the app
/// against the Firebase Local Emulator Suite (project `demo-devotion`).
/// Ignored in release builds.
const _useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
const _emulatorHost = String.fromEnvironment('EMULATOR_HOST');

const emulatorProjectId = 'demo-devotion';

FirebaseOptions _emulatorOptions() => FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: Platform.isIOS
      ? '1:000000000000:ios:0000000000000000'
      : '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: emulatorProjectId,
  storageBucket: '$emulatorProjectId.appspot.com',
);

/// Initializes Firebase. Returns a setup error message instead of throwing so
/// the app can show configuration guidance rather than crash.
Future<String?> bootstrapFirebase() async {
  try {
    if (_useEmulators && !kReleaseMode) {
      await Firebase.initializeApp(options: _emulatorOptions());
      final host = _emulatorHost.isNotEmpty
          ? _emulatorHost
          : (Platform.isAndroid ? '10.0.2.2' : 'localhost');
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      return null;
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return null;
  } on UnsupportedError catch (e) {
    return e.message ?? 'Firebase is not configured for this platform.';
  } on FirebaseException catch (e) {
    return 'Firebase failed to initialize (${e.code}).';
  }
}
