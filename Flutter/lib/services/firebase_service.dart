import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _initialized = true;
        return;
      }

      // Initializes Firebase directly using native platform configuration
      // (google-services.json on Android / GoogleService-Info.plist on iOS)
      await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      // Fallback state if native config files are missing or invalid
      _initialized = false;
    }
  }
}