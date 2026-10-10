// PLACEHOLDER — replace by running `flutterfire configure` (see README.md).
//
// No Firebase project has been configured for this repository yet. Until it
// is, the app shows a setup screen, or can run against the local emulators
// with `--dart-define=USE_FIREBASE_EMULATORS=true`.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase has not been configured. Run `flutterfire configure` to generate '
    'lib/firebase_options.dart, or start the app with '
    '--dart-define=USE_FIREBASE_EMULATORS=true for local development.',
  );
}
