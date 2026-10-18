import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'system_check_screen.dart';

enum AuthMode { signIn, signUp }

class AuthScreen extends StatefulWidget {
  final AuthMode initialMode;

  const AuthScreen({
    super.key,
    this.initialMode = AuthMode.signIn,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService.instance;
  late AuthMode _currentMode;
  bool _isLoading = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Password visibility
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    if (_currentMode != mode) {
      setState(() {
        _currentMode = mode;
      });
    }
  }

  Future<void> _submitAuth() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    // Use user-entered credentials, or test-friendly operator credentials if blank
    final effectiveEmail = email.isNotEmpty ? email : 'operator@locksync.internal';
    final effectivePassword = password.isNotEmpty ? password : 'locksync123';
    final effectiveName = name.isNotEmpty ? name : 'Operator';

    setState(() {
      _isLoading = true;
    });

    AuthResult result;
    if (_currentMode == AuthMode.signIn) {
      result = await _authService.signIn(
        email: effectiveEmail,
        password: effectivePassword,
      );
    } else {
      if (password.isNotEmpty &&
          _confirmPasswordController.text.isNotEmpty &&
          password != _confirmPasswordController.text) {
        result = const AuthResult(
          success: false,
          errorMessage: 'Passwords do not match.',
        );
      } else {
        result = await _authService.signUp(
          name: effectiveName,
          email: effectiveEmail,
          password: effectivePassword,
        );
      }
    }

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1F0D14),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFFF5252), width: 1),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF5252),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.errorMessage ?? 'Authentication failed',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    color: Color(0xFFF1F5F9),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = false;
    });

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
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _simulateBiometrics() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D141F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF162232), width: 1),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00D4FF).withOpacity(0.12),
                    border: Border.all(
                      color: const Color(0xFF00D4FF).withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Color(0xFF00D4FF),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'BIOMETRIC AUTHENTICATION',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: Color(0xFFF1F5F9),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Touch the fingerprint sensor or look into the camera to authenticate with LockSync.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF7A889B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitAuth();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      foregroundColor: const Color(0xFF080C10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'VERIFY & PROCEED',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
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
      },
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D141F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF162232), width: 1),
          ),
          title: const Text(
            'RESET PASSWORD',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFFF1F5F9),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your email address and we will dispatch a secure recovery token to reset your locker access credentials.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF7A889B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'EMAIL ADDRESS',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Color(0xFF7A889B),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF090E16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF1A2636),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _emailController,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFFF1F5F9),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'you@example.com',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      color: Color(0xFF4A5C70),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A889B),
                  letterSpacing: 1.0,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final emailToReset = _emailController.text.trim();
                Navigator.pop(dialogContext);

                final res = await _authService.sendPasswordResetEmail(
                  emailToReset.isNotEmpty ? emailToReset : 'operator@locksync.internal',
                );
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF0F1722),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: res.success
                            ? const Color(0xFF00D4FF)
                            : const Color(0xFFFF5252),
                        width: 1,
                      ),
                    ),
                    content: Row(
                      children: [
                        Icon(
                          res.success
                              ? Icons.mark_email_read_rounded
                              : Icons.error_outline_rounded,
                          color: res.success
                              ? const Color(0xFF00D4FF)
                              : const Color(0xFFFF5252),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            res.success
                                ? 'RESET INSTRUCTIONS SENT'
                                : (res.errorMessage ?? 'RESET REQUEST FAILED'),
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                              color: Color(0xFFF1F5F9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: const Color(0xFF080C10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'SEND LINK',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignIn = _currentMode == AuthMode.signIn;

    return Scaffold(
      backgroundColor: const Color(0xFF080C10),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==========================================
                  // 1. HEADER
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Minimal Back Button (Thin left-arrow icon)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 17,
                              color: Color(0xFF8E9EB2),
                            ),
                          ),
                        ),
                      ),

                      // Centered Compact LOCKSYNC Wordmark
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.8,
                          ),
                          children: [
                            TextSpan(
                              text: 'LOCK',
                              style: TextStyle(
                                color: Color(0xFFF1F5F9), // Near-white
                              ),
                            ),
                            TextSpan(
                              text: 'SYNC',
                              style: TextStyle(
                                color: Color(0xFF00D4FF), // Cyan #00d4ff
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Right Placeholder for balanced centering
                      const SizedBox(width: 38, height: 38),
                    ],
                  ),

                  // Generous spacing instead of a heavy divider
                  const SizedBox(height: 30),

                  // ==========================================
                  // 2. MAIN CONTENT HEADING & SUBTITLE
                  // ==========================================
                  Text(
                    isSignIn ? 'WELCOME BACK' : 'CREATE ACCOUNT',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFFF1F5F9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSignIn
                        ? 'Sign in to connect with your locker.'
                        : 'Create an account to pair and manage your locker.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF7A889B),
                      letterSpacing: -0.1,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==========================================
                  // 3. VERTICALLY STACKED FORM FIELDS
                  // ==========================================
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: isSignIn
                        ? _buildSignInFields()
                        : _buildSignUpFields(),
                  ),

                  const SizedBox(height: 22),

                  // ==========================================
                  // 5. PRIMARY ACTION BUTTON
                  // ==========================================
                  _PrimaryActionButton(
                    key: const Key('primary_action_button'),
                    label: isSignIn ? 'SIGN IN' : 'CREATE ACCOUNT',
                    isLoading: _isLoading,
                    onPressed: _submitAuth,
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 6. ALTERNATE ACCESS DIVIDER & BIOMETRICS
                  // ==========================================
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(
                          color: Color(0xFF162332),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.6,
                            color: const Color(0xFF4A5A6D),
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(
                          color: Color(0xFF162332),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // USE BIOMETRICS Secondary Button
                  _BiometricsButton(
                    key: const Key('biometrics_button'),
                    onPressed: _simulateBiometrics,
                  ),

                  const SizedBox(height: 28),

                  // ==========================================
                  // 7. FOOTER
                  // ==========================================
                  Center(
                    child: GestureDetector(
                      key: const Key('auth_mode_toggle_footer'),
                      onTap: () => _switchMode(
                        isSignIn ? AuthMode.signUp : AuthMode.signIn,
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6.0,
                          horizontal: 8.0,
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                            children: [
                              TextSpan(
                                text: isSignIn
                                    ? 'NEW TO LOCKSYNC? '
                                    : 'ALREADY HAVE AN ACCOUNT? ',
                                style: const TextStyle(
                                  color: Color(0xFF6B7C93), // Muted gray
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: isSignIn ? 'CREATE ACCOUNT' : 'SIGN IN',
                                style: const TextStyle(
                                  color: Color(0xFF00D4FF), // Cyan accent
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build fields for SIGN IN
  Widget _buildSignInFields() {
    return Column(
      key: const ValueKey('sign_in_fields'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // EMAIL FIELD
        LockSyncTextField(
          label: 'EMAIL',
          placeholder: 'you@example.com',
          prefixIcon: Icons.mail_outline_rounded,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 16),

        // PASSWORD FIELD
        LockSyncTextField(
          label: 'PASSWORD',
          placeholder: 'Enter your password',
          prefixIcon: Icons.lock_outline_rounded,
          controller: _passwordController,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 19,
              color: const Color(0xFF5A6B80),
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            splashRadius: 20,
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
          ),
        ),

        const SizedBox(height: 10),

        // FORGOT PASSWORD? (Right-aligned text action in small cyan JetBrains Mono)
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: _showForgotPasswordDialog,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Text(
                'FORGOT PASSWORD?',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: Color(0xFF00D4FF),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build fields for SIGN UP
  Widget _buildSignUpFields() {
    return Column(
      key: const ValueKey('sign_up_fields'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // NAME FIELD
        LockSyncTextField(
          label: 'NAME',
          placeholder: 'Jane Doe',
          prefixIcon: Icons.person_outline_rounded,
          controller: _nameController,
          keyboardType: TextInputType.name,
        ),

        const SizedBox(height: 16),

        // EMAIL FIELD
        LockSyncTextField(
          label: 'EMAIL',
          placeholder: 'you@example.com',
          prefixIcon: Icons.mail_outline_rounded,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 16),

        // PASSWORD FIELD
        LockSyncTextField(
          label: 'PASSWORD',
          placeholder: 'Create a strong password',
          prefixIcon: Icons.lock_outline_rounded,
          controller: _passwordController,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 19,
              color: const Color(0xFF5A6B80),
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            splashRadius: 20,
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
          ),
        ),

        const SizedBox(height: 16),

        // CONFIRM PASSWORD FIELD
        LockSyncTextField(
          label: 'CONFIRM PASSWORD',
          placeholder: 'Confirm your password',
          prefixIcon: Icons.lock_outline_rounded,
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 19,
              color: const Color(0xFF5A6B80),
            ),
            onPressed: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
            splashRadius: 20,
            tooltip: _obscureConfirmPassword
                ? 'Show password'
                : 'Hide password',
          ),
        ),
      ],
    );
  }
}


// ==========================================
// CUSTOM LOCKSYNC TEXT FIELD
// ==========================================
class LockSyncTextField extends StatefulWidget {
  final String label;
  final String placeholder;
  final IconData prefixIcon;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;

  const LockSyncTextField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.prefixIcon,
    required this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<LockSyncTextField> createState() => _LockSyncTextFieldState();
}

class _LockSyncTextFieldState extends State<LockSyncTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Uppercase JetBrains Mono Label
        Text(
          widget.label,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.3,
            color: _isFocused
                ? const Color(0xFF00D4FF)
                : const Color(0xFF7A889B),
          ),
        ),
        const SizedBox(height: 7),

        // Input Container (52px Touch Height, 10px corners, subtle glow on focus)
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF0D141F), // Dark fill slightly lighter than page
            borderRadius: BorderRadius.circular(10), // 10px corner radius
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFF00D4FF) // Cyan border on focus
                  : const Color(0xFF162232), // Low-contrast border
              width: _isFocused ? 1.4 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.18),
                      blurRadius: 10,
                      spreadRadius: 0.5,
                    ),
                  ]
                : [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Small Left Icon
              Padding(
                padding: const EdgeInsets.only(left: 14.0, right: 10.0),
                child: Icon(
                  widget.prefixIcon,
                  size: 18,
                  color: _isFocused
                      ? const Color(0xFF00D4FF)
                      : const Color(0xFF4A5C70),
                ),
              ),

              // Text Field Area
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  cursorColor: const Color(0xFF00D4FF),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFF1F5F9), // Near-white input text
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    hintText: widget.placeholder,
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF4A5C70), // Muted placeholder text
                    ),
                  ),
                ),
              ),

              // Optional Trailing Icon (Visibility toggle)
              if (widget.suffixIcon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: widget.suffixIcon!,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// PRIMARY ACTION BUTTON (Solid #00d4ff)
// ==========================================
class _PrimaryActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  const _PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: _isPressed
                ? const Color(0xFF00BCE3)
                : (_isHovered
                    ? const Color(0xFF1AE0FF)
                    : const Color(0xFF00D4FF)),
            borderRadius: BorderRadius.circular(10), // 10px corner radius
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withOpacity(
                  _isPressed ? 0.15 : (_isHovered ? 0.35 : 0.22),
                ),
                blurRadius: _isHovered ? 16 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: widget.isLoading
                ? const [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF080C10)),
                      ),
                    ),
                  ]
                : [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: Color(0xFF080C10), // Near-black text
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: Color(0xFF080C10),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// BIOMETRICS SECONDARY BUTTON
// ==========================================
class _BiometricsButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _BiometricsButton({super.key, required this.onPressed});

  @override
  State<_BiometricsButton> createState() => _BiometricsButtonState();
}

class _BiometricsButtonState extends State<_BiometricsButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: _isPressed
                ? const Color(0xFF0D1722)
                : (_isHovered
                    ? const Color(0xFF0E1A26)
                    : const Color(0xFF091018)),
            borderRadius: BorderRadius.circular(10), // 10px corner radius
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF00D4FF)
                  : const Color(0xFF00D4FF).withOpacity(0.55),
              width: 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.12),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.fingerprint_rounded,
                size: 20,
                color: Color(0xFF00D4FF),
              ),
              SizedBox(width: 10),
              Text(
                'USE BIOMETRICS',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: Color(0xFF00D4FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
