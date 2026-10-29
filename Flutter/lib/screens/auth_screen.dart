import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../widgets/locksync_text_field.dart';
import 'main_screen.dart';

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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(_clearErrorOnInput);
  }

  @override
  void dispose() {
    _pinController.removeListener(_clearErrorOnInput);
    _pinController.dispose();
    super.dispose();
  }

  void _clearErrorOnInput() {
    // Only clear error when active input text exists (prevents _pinController.clear() from wiping state prematurely)
    if (_errorMessage != null && _pinController.text.isNotEmpty) {
      setState(() => _errorMessage = null);
    }
  }

  // --- Logic & Actions ---

  Future<void> _submitPin() async {
    if (_isLoading) return;

    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMessage = AppStrings.enterPinPrompt);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.verifyPinAndUnlock(pin);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      setState(() {
        _errorMessage = result.errorMessage ?? AppStrings.accessDenied;
      });
      _pinController.clear();
      return;
    }

    _navigateToMain();
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      PageTransition(
        type: PageTransitionType.rightToLeftWithFade,
        duration: AppDimensions.animDurationStandard,
        child: const MainScreen(),
      ),
    );
  }

  // --- UI Build Shell ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
            vertical: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. PINNED TOP-LEFT LOGO
              _buildHeaderLogo(),

              // 2. VERTICALLY CENTERED FORM
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeadingSection(),
                        const SizedBox(height: 32),
                        _buildPinInput(),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          _buildErrorMessage(),
                        ],
                        const SizedBox(height: 24),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Extracted Modular Components ---

  Widget _buildHeaderLogo() {
    return Align(
      alignment: Alignment.centerLeft,
      child: RichText(
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
    );
  }

  Widget _buildHeadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(AppStrings.pageTitle, style: AppTextStyles.heading),
        Text(AppStrings.pageSubtitle, style: AppTextStyles.subtitle),
      ],
    );
  }

  Widget _buildPinInput() {
    return LockSyncTextField(
      label: AppStrings.masterPinLabel,
      placeholder: AppStrings.masterPinPlaceholder,
      prefixIcon: Icons.pin_outlined,
      controller: _pinController,
      obscureText: _obscurePin,
      keyboardType: TextInputType.number,
      onChanged: (_) => _clearErrorOnInput(),
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePin
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
          color: AppColors.textSubtle,
        ),
        onPressed: () => setState(() => _obscurePin = !_obscurePin),
        splashRadius: 24,
        tooltip: _obscurePin ? 'Show PIN' : 'Hide PIN',
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: AppColors.errorRed,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _errorMessage!,
            style: const TextStyle(
              fontFamily: AppTextStyles.fontSans,
              fontSize: 12,
              color: AppColors.errorRed,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitPin,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cyanAccent,
        foregroundColor: AppColors.background,
        disabledBackgroundColor: AppColors.cyanAccent.withValues(alpha: 0.5),
        minimumSize: const Size.fromHeight(AppDimensions.primaryButtonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        elevation: 0,
      ),
      child: _isLoading ? _buildButtonSpinner() : _buildButtonLabel(),
    );
  }

  Widget _buildButtonSpinner() {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppColors.background,
      ),
    );
  }

  Widget _buildButtonLabel() {
    return const Text(
      AppStrings.unlockTerminal,
      style: AppTextStyles.buttonLabel,
    );
  }
}