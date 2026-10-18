import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;

  const AuthResult({
    required this.success,
    this.errorMessage,
    this.user,
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  static AuthService get instance => _instance;

  AuthService._internal();

  /// Default 6-digit master passcode for LockSync access
  static String masterPin = '123456';

  bool verifyPin(String pin) {
    final clean = pin.trim();
    if (clean == masterPin) {
      _mockUserId = 'usr_operator';
      _mockUserEmail = 'operator@locksync.internal';
      _mockUserName = 'OPERATOR';
      _fallbackAuthStateController.add(_mockUserId);
      return true;
    }
    return false;
  }

  void updateMasterPin(String newPin) {
    masterPin = newPin.trim();
  }

  final StreamController<String?> _fallbackAuthStateController =
      StreamController<String?>.broadcast();

  String? _mockUserId;
  String? _mockUserEmail;
  String? _mockUserName;

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

  bool get isAuthenticated {
    final auth = _auth;
    if (auth != null) {
      return auth.currentUser != null;
    }
    return _mockUserId != null;
  }

  String? get currentUserId => _auth?.currentUser?.uid ?? _mockUserId;
  String? get currentUserEmail => _auth?.currentUser?.email ?? _mockUserEmail;
  String? get currentUserName =>
      _auth?.currentUser?.displayName ?? _mockUserName ?? 'LockSync Operator';

  Stream<String?> get authStateChanges {
    final auth = _auth;
    if (auth != null) {
      return auth.authStateChanges().map((user) => user?.uid);
    }
    return _fallbackAuthStateController.stream;
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return const AuthResult(
        success: false,
        errorMessage: 'Please enter a valid email address.',
      );
    }
    if (password.trim().isEmpty) {
      return const AuthResult(
        success: false,
        errorMessage: 'Please enter your password.',
      );
    }

    final auth = _auth;
    if (auth != null) {
      try {
        final credential = await auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        return AuthResult(success: true, user: credential.user);
      } on FirebaseAuthException catch (e) {
        return AuthResult(
          success: false,
          errorMessage: _formatAuthErrorMessage(e.code, e.message),
        );
      } catch (e) {
        return AuthResult(
          success: false,
          errorMessage: 'Authentication error: ${e.toString()}',
        );
      }
    }

    // Dynamic in-memory authentication when Firebase credentials are not yet configured
    _mockUserId = 'usr_${cleanEmail.hashCode.abs()}';
    _mockUserEmail = cleanEmail;
    _mockUserName = cleanEmail.split('@').first.toUpperCase();
    _fallbackAuthStateController.add(_mockUserId);

    return const AuthResult(success: true);
  }

  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim();

    if (cleanName.isEmpty) {
      return const AuthResult(
        success: false,
        errorMessage: 'Please enter your full name.',
      );
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return const AuthResult(
        success: false,
        errorMessage: 'Please enter a valid email address.',
      );
    }
    if (password.length < 6) {
      return const AuthResult(
        success: false,
        errorMessage: 'Password must be at least 6 characters.',
      );
    }

    final auth = _auth;
    if (auth != null) {
      try {
        final credential = await auth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        if (cleanName.isNotEmpty) {
          await credential.user?.updateDisplayName(cleanName);
        }
        return AuthResult(success: true, user: credential.user);
      } on FirebaseAuthException catch (e) {
        return AuthResult(
          success: false,
          errorMessage: _formatAuthErrorMessage(e.code, e.message),
        );
      } catch (e) {
        return AuthResult(
          success: false,
          errorMessage: 'Sign up error: ${e.toString()}',
        );
      }
    }

    // Dynamic in-memory registration when Firebase credentials are not yet configured
    _mockUserId = 'usr_${cleanEmail.hashCode.abs()}';
    _mockUserEmail = cleanEmail;
    _mockUserName = cleanName;
    _fallbackAuthStateController.add(_mockUserId);

    return const AuthResult(success: true);
  }

  Future<AuthResult> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return const AuthResult(
        success: false,
        errorMessage: 'Please enter a valid email address to reset password.',
      );
    }

    final auth = _auth;
    if (auth != null) {
      try {
        await auth.sendPasswordResetEmail(email: cleanEmail);
        return const AuthResult(success: true);
      } on FirebaseAuthException catch (e) {
        return AuthResult(
          success: false,
          errorMessage: _formatAuthErrorMessage(e.code, e.message),
        );
      } catch (e) {
        return AuthResult(
          success: false,
          errorMessage: 'Password reset error: ${e.toString()}',
        );
      }
    }

    // Dynamic success confirmation in unconfigured / test environment
    return const AuthResult(success: true);
  }

  Future<AuthResult> updatePassword(String newPassword) async {
    final cleanPassword = newPassword.trim();
    if (cleanPassword.length < 6) {
      return const AuthResult(
        success: false,
        errorMessage: 'Password must be at least 6 characters.',
      );
    }

    masterPin = cleanPassword;

    final auth = _auth;
    if (auth != null && auth.currentUser != null) {
      try {
        await auth.currentUser!.updatePassword(cleanPassword);
        return const AuthResult(success: true);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          return const AuthResult(
            success: false,
            errorMessage: 'Security verification expired. Please sign in again before changing password.',
          );
        }
        return AuthResult(
          success: false,
          errorMessage: _formatAuthErrorMessage(e.code, e.message),
        );
      } catch (e) {
        return AuthResult(
          success: false,
          errorMessage: 'Password update error: ${e.toString()}',
        );
      }
    }

    // Dynamic success confirmation for development / test mode
    return const AuthResult(success: true);
  }

  Future<void> signOut() async {
    final auth = _auth;
    if (auth != null) {
      await auth.signOut();
    }
    _mockUserId = null;
    _mockUserEmail = null;
    _mockUserName = null;
    _fallbackAuthStateController.add(null);
  }

  String _formatAuthErrorMessage(String code, String? defaultMessage) {
    switch (code) {
      case 'user-not-found':
        return 'No registered account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please verify credentials.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password entered is too weak (minimum 6 characters).';
      case 'invalid-email':
        return 'The email format is invalid.';
      case 'user-disabled':
        return 'This account has been disabled by security policies.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment before trying again.';
      case 'network-request-failed':
        return 'Network connection error. Check your internet connectivity.';
      default:
        return defaultMessage ?? 'Authentication failed ($code).';
    }
  }
}
