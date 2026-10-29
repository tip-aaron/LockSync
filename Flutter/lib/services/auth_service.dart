import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;

  const AuthResult({required this.success, this.errorMessage, this.user});
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  static AuthService get instance => _instance;

  AuthService._internal();

  /// In-memory Master PIN passcode (default: 123456)
  static String _masterPin = '123456';

  /// Session flag indicating whether the user unlocked the app via PIN
  bool _isAppUnlocked = false;

  bool get isAppUnlocked => _isAppUnlocked;

  FirebaseAuth? get _auth {
    if (FirebaseService.isInitialized) {
      try {
        return FirebaseAuth.instance;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Get current Firebase anonymous user ID
  String? get currentUserId => _auth?.currentUser?.uid ?? 'anon_operator';

  /// Stream Firebase auth state changes
  Stream<User?> get authStateChanges {
    final auth = _auth;
    if (auth != null) {
      return auth.authStateChanges();
    }
    return Stream.value(null);
  }

  /// Unlocks the app after a successful biometric check
  Future<AuthResult> unlockWithBiometrics() async {
    _isAppUnlocked = true;
    await ensureAnonymousAuth();
    return AuthResult(success: true, user: _auth?.currentUser);
  }

  /// Silently signs in to Firebase anonymously in the background
  Future<AuthResult> ensureAnonymousAuth() async {
    final auth = _auth;
    if (auth == null) {
      return const AuthResult(success: true);
    }

    try {
      if (auth.currentUser == null) {
        final credential = await auth.signInAnonymously();
        return AuthResult(success: true, user: credential.user);
      }
      return AuthResult(success: true, user: auth.currentUser);
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Anonymous authentication failed: ${e.toString()}',
      );
    }
  }

  /// Verifies the entered PIN against the in-memory master PIN
  Future<AuthResult> verifyPinAndUnlock(String pin) async {
    final clean = pin.trim();
    if (clean == _masterPin) {
      _isAppUnlocked = true;
      await ensureAnonymousAuth();
      return AuthResult(success: true, user: _auth?.currentUser);
    }

    return const AuthResult(
      success: false,
      errorMessage: 'Incorrect PIN passcode. Please try again.',
    );
  }

  /// Updates the master PIN in runtime memory
  AuthResult updateMasterPin({
    required String currentPin,
    required String newPin,
  }) {
    if (currentPin.trim() != _masterPin) {
      return const AuthResult(
        success: false,
        errorMessage: 'Current PIN is incorrect.',
      );
    }

    final cleanNew = newPin.trim();

    if (cleanNew.length < 4 || cleanNew.length > 8) {
      return const AuthResult(
        success: false,
        errorMessage: 'New PIN must be between 4 and 8 digits.',
      );
    }

    _masterPin = cleanNew;

    return const AuthResult(success: true);
  }

  void lockApp() {
    _isAppUnlocked = false;
  }
}