import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color background = Color(0xFF080C10);
  static const Color cardBackground = Color(0xFF0D141F);
  static const Color inputBackground = Color(0xFF090E16);
  static const Color borderSubtle = Color(0xFF162232);
  static const Color borderDivider = Color(0xFF162332);
  static const Color borderInput = Color(0xFF1A2636);
  static const Color successGreen = Color(0xFF00E676);
  static const Color cyanAccent = Color(0xFF00D4FF);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF7A889B);
  static const Color textMuted = Color(0xFF4A5C70);
  static const Color textSubtle = Color(0xFF5A6B80);
  static const Color textHeaderIcon = Color(0xFF8E9EB2);
  static const Color textDivider = Color(0xFF4A5A6D);

  static const Color errorBackground = Color(0xFF1F0D14);
  static const Color errorRed = Color(0xFFFF5252);
  static const Color successBackground = Color(0xFF0F1722);
}

abstract final class AppDimensions {
  static const double maxContentWidth = 390.0;
  static const double headerButtonSize = 38.0;
  static const double primaryButtonHeight = 52.0;
  static const double secondaryButtonHeight = 48.0;
  static const double inputFieldHeight = 52.0;
  static const double dialogInputFieldHeight = 48.0;
  static const double avatarSize = 58.0;

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 10.0;
  static const double radiusLarge = 14.0;
  static const double radiusCircular = 20.0;

  static const Duration animDurationFast = Duration(milliseconds: 180);
  static const Duration animDurationStandard = Duration(milliseconds: 300);
}

abstract final class AppTextStyles {
  static const String fontMono = 'JetBrains Mono';
  static const String fontSans = 'Inter';

  static const TextStyle logoWhite = TextStyle(
    fontFamily: fontMono,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    color: AppColors.textPrimary,
  );

  static const TextStyle logoCyan = TextStyle(
    fontFamily: fontMono,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    color: AppColors.cyanAccent,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: fontMono,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: fontSans,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontFamily: fontMono,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.3,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontMono,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
  );

  static const TextStyle actionLink = TextStyle(
    fontFamily: fontMono,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: AppColors.cyanAccent,
  );
}

class SensorLimits {
  /// Max fingerprint templates the ES608 sensor can store.
  static const int maxFingerprintSlots = 162;
}

abstract final class AppStrings {
  static const String appTitlePart1 = 'LOCK';
  static const String appTitlePart2 = 'SYNC';
  static const String appTitle = "$appTitlePart1 $appTitlePart2";
  static const String pageTitle = 'SECURITY ACCESS';
  static const String pageSubtitle =
      'Enter your Master PIN to enter the app.';
  static const String masterPinLabel = 'MASTER PIN';
  static const String masterPinPlaceholder = 'Enter 6-digit PIN';
  static const String changeMasterPin = 'CHANGE MASTER PIN?';
  static const String unlockTerminal = 'UNLOCK TERMINAL';
  static const String dividerBiometrics = 'OR USE BIOMETRICS';
  static const String scanBiometricKey = 'SCAN BIOMETRIC KEY';
  static const String enterPinPrompt = 'Please enter your Master PIN.';
  static const String accessDenied = 'Access Denied';

  static const String updatePinTitle = 'UPDATE MASTER PIN';
  static const String updatePinSubtitle =
      'Modify the Master Passcode used to unlock this LockSync terminal session.';
  static const String currentPinLabel = 'CURRENT PIN';
  static const String newPinLabel = 'NEW PIN (4-8 DIGITS)';
  static const String confirmPinLabel = 'CONFIRM NEW PIN';
  static const String cancel = 'CANCEL';
  static const String savePin = 'SAVE PIN';
  static const String pinMismatchError = 'New PINs do not match.';
  static const String pinSuccess = 'Master PIN successfully updated.';

  static const String biometricTitle = 'BIOMETRIC AUTHENTICATION';
  static const String biometricVerifying =
      'Verifying biometric telemetry & pairing session...';
  static const String biometricPrompt =
      'Touch the fingerprint scanner or use device biometrics to unlock.';
  static const String verifyAndUnlock = 'VERIFY & UNLOCK';
}
