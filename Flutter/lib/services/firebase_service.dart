import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class FirebaseService {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    try {
      if (DefaultFirebaseOptions.isConfigured) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _initialized = true;
      } else if (Firebase.apps.isNotEmpty) {
        _initialized = true;
      } else {
        // Attempt platform initialization if possible
        try {
          await Firebase.initializeApp();
          _initialized = true;
        } catch (_) {
          // If no platform configuration exists (e.g. testing or before flutterfire config),
          // continue gracefully in dynamic fallback mode
          _initialized = false;
        }
      }
    } catch (_) {
      _initialized = false;
    }
  }
}
