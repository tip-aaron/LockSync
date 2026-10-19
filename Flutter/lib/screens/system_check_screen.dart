import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/lock_service.dart';
import 'auth_screen.dart';
import 'lock_control_screen.dart';

enum SystemPhase {
  checking,    // Circular ring progress is filling (0% -> 100%)
  ringExiting, // Ring and brand fade out
  paused,      // Screen pause for 1.0s after ring fades out
  welcome,     // "WELCOME TO LOCKSYNC" fades in & holds for 1.5s
  offline,     // Ring turns red, SYSTEM OFFLINE & retry actions appear
}

/// Loading screen acting as a hardware check before transitioning to the lock screen.
class SystemCheckScreen extends StatefulWidget {
  final bool? forceOffline;
  final Duration checkDuration;
  final Duration ringFadeDuration;
  final Duration pauseBeforeWelcomeDuration;
  final Duration welcomeFadeDuration;
  final Duration holdDuration;
  final Duration fadeDuration;

  const SystemCheckScreen({
    super.key,
    this.forceOffline,
    this.checkDuration = const Duration(milliseconds: 1400),
    this.ringFadeDuration = const Duration(milliseconds: 300),
    this.pauseBeforeWelcomeDuration = const Duration(milliseconds: 1000),
    this.welcomeFadeDuration = const Duration(milliseconds: 350),
    this.holdDuration = const Duration(milliseconds: 1500),
    this.fadeDuration = const Duration(milliseconds: 400),
  });

  @override
  State<SystemCheckScreen> createState() => _SystemCheckScreenState();
}

class _SystemCheckScreenState extends State<SystemCheckScreen>
    with TickerProviderStateMixin {
  late SystemPhase _phase;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  late AnimationController _ringFadeController;
  late Animation<double> _ringFadeAnimation;

  late AnimationController _welcomeFadeController;
  late Animation<double> _welcomeFadeAnimation;

  Timer? _pauseTimer;
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();
    _phase = SystemPhase.checking;

    // 1. Progress bar animation for the circular ring
    _progressController = AnimationController(
      vsync: this,
      duration: widget.checkDuration,
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );

    // 2. Fade-out animation for the ring and LOCKSYNC
    _ringFadeController = AnimationController(
      vsync: this,
      duration: widget.ringFadeDuration,
    );
    _ringFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ringFadeController, curve: Curves.easeOut),
    );

    // 3. Fade-in animation for "WELCOME TO LOCKSYNC"
    _welcomeFadeController = AnimationController(
      vsync: this,
      duration: widget.welcomeFadeDuration,
    );
    _welcomeFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _welcomeFadeController, curve: Curves.easeIn),
    );

    // Listen for progress completion
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onProgressCompleted();
      }
    });

    _startChecking();
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _transitionTimer?.cancel();
    _progressController.dispose();
    _ringFadeController.dispose();
    _welcomeFadeController.dispose();
    super.dispose();
  }

  void _startChecking() {
    setState(() => _phase = SystemPhase.checking);

    _pauseTimer?.cancel();
    _transitionTimer?.cancel();
    _ringFadeController.reset();
    _welcomeFadeController.reset();
    _progressController.reset();
    _progressController.forward();
  }

  void _onProgressCompleted() async {
    if (!mounted) return;

    bool isOffline;
    if (widget.forceOffline != null) {
      isOffline = widget.forceOffline!;
    } else {
      try {
        // Stream the live locker node directly from Firebase RTDB with a timeout fallback
        final device = await LockService.instance
            .streamLock()
            .first
            .timeout(const Duration(seconds: 3));
        isOffline = device == null;
      } catch (_) {
        isOffline = true;
      }
    }

    if (!mounted) return;

    if (isOffline) {
      setState(() => _phase = SystemPhase.offline);
    } else {
      // Step A: Progress complete -> let ring and brand fade out
      setState(() => _phase = SystemPhase.ringExiting);
      _ringFadeController.forward().then((_) {
        if (!mounted) return;

        setState(() => _phase = SystemPhase.paused);

        // Step B: After 1.0s pause, let "WELCOME TO LOCKSYNC" appear
        _pauseTimer?.cancel();
        _pauseTimer = Timer(widget.pauseBeforeWelcomeDuration, () {
          if (!mounted) return;

          setState(() => _phase = SystemPhase.welcome);
          _welcomeFadeController.forward().then((_) {
            if (!mounted) return;

            // Step C: Hold, then transition into LockControlScreen
            _transitionTimer?.cancel();
            _transitionTimer = Timer(widget.holdDuration, () {
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const LockControlScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: widget.fadeDuration,
                ),
              );
            });
          });
        });
      });
    }
  }

  void _retryConnection() {
    _startChecking();
  }

  void _returnToSignIn() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: AppDimensions.animDurationStandard,
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
            child: Column(
              children: [
                const SizedBox(height: 28),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 12.0,
                      ),
                      child: _buildCenterStage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterStage() {
    return switch (_phase) {
      SystemPhase.welcome => FadeTransition(
          opacity: _welcomeFadeAnimation,
          child: _buildWelcomeContent(),
        ),
      SystemPhase.paused => const SizedBox.shrink(),
      _ => FadeTransition(
          opacity: _ringFadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProgressRingWithBrand(),
              if (_phase == SystemPhase.offline) ...[
                const SizedBox(height: 36),
                _buildOfflineControls(),
              ],
            ],
          ),
        ),
    };
  }

  Widget _buildProgressRingWithBrand() {
    final bool isOffline = _phase == SystemPhase.offline;
    final Color ringColor = isOffline ? AppColors.errorRed : AppColors.cyanAccent;

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: ringColor.withValues(alpha: isOffline ? 0.30 : 0.22),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 4.0,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.borderSubtle,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              final double value = isOffline ? 1.0 : _progressAnimation.value;
              return SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 4.0,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                ),
              );
            },
          ),
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
        ],
      ),
    );
  }

  Widget _buildOfflineControls() {
    return Column(
      key: const Key('offline_state'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.errorRed.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            border: Border.all(
              color: AppColors.errorRed.withValues(alpha: 0.4),
            ),
          ),
          child: const Text(
            'CONNECTION FAILED',
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.errorRed,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'SYSTEM OFFLINE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Cannot reach Locker 01 hardware. Access restricted until hardware comes online.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTextStyles.fontSans,
            fontSize: 12.5,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: AppDimensions.dialogInputFieldHeight,
          child: ElevatedButton.icon(
            key: const Key('retry_connection_button'),
            onPressed: _retryConnection,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'RETRY CONNECTION',
              style: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanAccent,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: AppDimensions.dialogInputFieldHeight,
          child: OutlinedButton(
            key: const Key('back_to_sign_in_button'),
            onPressed: _returnToSignIn,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.borderSubtle, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMedium),
              ),
            ),
            child: const Text(
              'BACK TO SIGN IN',
              style: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeContent() {
    return const Center(
      key: Key('online_verified_state'),
      child: Text(
        'WELCOME TO LOCKSYNC',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTextStyles.fontMono,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.2,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}