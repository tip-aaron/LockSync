import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../widgets/biometric_auth_bottom_sheet.dart';
import '../widgets/change_pin_dialog.dart';
import '../widgets/locksync_text_field.dart';
import 'system_check_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService.instance;
  final TextEditingController _pinController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    if (_isLoading) return;

    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      _showSnackBar(AppStrings.enterPinPrompt, isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.verifyPinAndUnlock(pin);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (!result.success) {
      _showSnackBar(result.errorMessage ?? AppStrings.accessDenied, isError: true);
      _pinController.clear();
      return;
    }

    _navigateToSystemCheck();
  }

  Future<void> _unlockWithBiometrics() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final result = await _authService.unlockWithBiometrics();

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (!result.success) {
      _showSnackBar(result.errorMessage ?? AppStrings.accessDenied, isError: true);
      return;
    }

    _navigateToSystemCheck();
  }

  void _navigateToSystemCheck() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SystemCheckScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.04, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(tween),
              child: child,
            ),
          );
        },
        transitionDuration: AppDimensions.animDurationStandard,
      ),
    );
  }

  void _showChangePinDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => ChangePinDialog(
        onShowSnackBar: _showSnackBar,
      ),
    );
  }

  void _simulateBiometrics() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusCircular),
        ),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      builder: (modalContext) => BiometricAuthBottomSheet(
        onSuccess: _unlockWithBiometrics,
        onError: _showSnackBar,
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            isError ? AppColors.errorBackground : AppColors.successBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          side: BorderSide(
            color: isError ? AppColors.errorRed : AppColors.cyanAccent,
            width: 1,
          ),
        ),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? AppColors.errorRed : AppColors.cyanAccent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: AppTextStyles.fontSans,
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. HEADER (centered wordmark, no back button)
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: AppStrings.appTitlePart1,
                            style: AppTextStyles.logoWhite,
                          ),
                          TextSpan(
                            text: AppStrings.appTitlePart2,
                            style: AppTextStyles.logoCyan,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 2. HEADING & SUBTITLE
                  const Text(
                    AppStrings.pageTitle,
                    style: AppTextStyles.heading,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    AppStrings.pageSubtitle,
                    style: AppTextStyles.subtitle,
                  ),

                  const SizedBox(height: 32),

                  // 3. MASTER PIN INPUT
                  LockSyncTextField(
                    label: AppStrings.masterPinLabel,
                    placeholder: AppStrings.masterPinPlaceholder,
                    prefixIcon: Icons.pin_outlined,
                    controller: _pinController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePin
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                        color: AppColors.textSubtle,
                      ),
                      onPressed: () {
                        setState(() => _obscurePin = !_obscurePin);
                      },
                      splashRadius: 20,
                      tooltip: _obscurePin ? 'Show PIN' : 'Hide PIN',
                    ),
                  ),

                  const SizedBox(height: 10),

                  // CHANGE PIN ACTION LINK
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: _showChangePinDialog,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall / 2),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Text(
                          AppStrings.changeMasterPin,
                          style: AppTextStyles.actionLink,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 4. UNLOCK BUTTON
                  SizedBox(
                    height: AppDimensions.primaryButtonHeight,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyanAccent,
                        foregroundColor: AppColors.background,
                        disabledBackgroundColor:
                            AppColors.cyanAccent.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusMedium),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.background,
                              ),
                            )
                          : const Text(
                              AppStrings.unlockTerminal,
                              style: AppTextStyles.buttonLabel,
                            ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 5. DIVIDER
                  Row(
                    children: const [
                      Expanded(
                        child: Divider(
                          color: AppColors.borderDivider,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          AppStrings.dividerBiometrics,
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontMono,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.6,
                            color: AppColors.textDivider,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppColors.borderDivider,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 6. BIOMETRICS BUTTON
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _simulateBiometrics,
                    icon: const Icon(
                      Icons.fingerprint_rounded,
                      size: 20,
                      color: AppColors.cyanAccent,
                    ),
                    label: const Text(
                      AppStrings.scanBiometricKey,
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontMono,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      fixedSize: const Size.fromHeight(
                        AppDimensions.secondaryButtonHeight,
                      ),
                      side: const BorderSide(
                        color: AppColors.borderSubtle,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                      backgroundColor: AppColors.cardBackground,
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}