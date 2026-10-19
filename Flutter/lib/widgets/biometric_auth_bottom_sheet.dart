import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';

class BiometricAuthBottomSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  final Function(String message, {bool isError}) onError;

  const BiometricAuthBottomSheet({
    super.key,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<BiometricAuthBottomSheet> createState() =>
      _BiometricAuthBottomSheetState();
}

class _BiometricAuthBottomSheetState extends State<BiometricAuthBottomSheet> {
  bool _isAuthenticating = false;

  Future<void> _handleBiometricAuth() async {
    setState(() => _isAuthenticating = true);

    final res = await AuthService.instance.ensureAnonymousAuth();

    if (!mounted) return;

    if (res.success) {
      Navigator.pop(context);
      widget.onSuccess();
    } else {
      setState(() => _isAuthenticating = false);
      Navigator.pop(context);
      widget.onError(
        res.errorMessage ?? 'Biometric auth failed',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppDimensions.avatarSize,
              height: AppDimensions.avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyanAccent.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.cyanAccent.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: _isAuthenticating
                  ? const Padding(
                      padding: EdgeInsets.all(14.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.cyanAccent,
                      ),
                    )
                  : const Icon(
                      Icons.fingerprint_rounded,
                      color: AppColors.cyanAccent,
                      size: 32,
                    ),
            ),
            const SizedBox(height: 16),
            const Text(
              AppStrings.biometricTitle,
              style: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isAuthenticating
                  ? AppStrings.biometricVerifying
                  : AppStrings.biometricPrompt,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontSans,
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.secondaryButtonHeight,
              child: ElevatedButton(
                onPressed: _isAuthenticating ? null : _handleBiometricAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyanAccent,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  AppStrings.verifyAndUnlock,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}