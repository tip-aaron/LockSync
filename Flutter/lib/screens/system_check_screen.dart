import 'dart:async';
import 'package:flutter/material.dart';
import '../services/lock_service.dart';
import 'auth_screen.dart';
import 'lock_control_screen.dart';

enum SystemPhase {
  checking,    // Circular ring progress is filling (0% -> 100%), only ring and LOCKSYNC visible
  ringExiting, // Ring and LOCKSYNC fade out
  paused,      // Screen pause for 1.0s after ring fades out
  welcome,     // "WELCOME TO LOCKSYNC" fades in & holds for 1.5s
  offline,     // Ring turns red, SYSTEM OFFLINE & retry actions appear
}

/// Loading screen acting as a hardware check before transitioning to the lock screen.
///
/// 1. Displays ONLY the circular ring progress bar with LOCKSYNC in the center (no extraneous text).
/// 2. Once the progress completes, the ring and LOCKSYNC fade out.
/// 3. After 1.0 second, "WELCOME TO LOCKSYNC" appears in the center.
/// 4. After staying for 1.5 seconds, the screen smoothly transitions into LockControlScreen.
/// 5. If offline: Halts progression, turns ring red/amber, displays "SYSTEM OFFLINE", offers retry.
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
    setState(() {
      _phase = SystemPhase.checking;
    });

    _pauseTimer?.cancel();
    _transitionTimer?.cancel();
    _ringFadeController.reset();
    _welcomeFadeController.reset();
    _progressController.reset();
    _progressController.forward();
  }

  void _onProgressCompleted() async {
    if (!mounted) return;

    final isOffline = widget.forceOffline ??
        !(await LockService.instance.checkSystemConnectivity());

    if (!mounted) return;

    if (isOffline) {
      setState(() {
        _phase = SystemPhase.offline;
      });
    } else {
      // Step A: Progress is complete -> let the ring and LOCKSYNC fade out
      setState(() {
        _phase = SystemPhase.ringExiting;
      });
      _ringFadeController.forward().then((_) {
        if (!mounted) return;

        setState(() {
          _phase = SystemPhase.paused;
        });

        // Step B: After 1.0s pause, let "WELCOME TO LOCKSYNC" appear
        _pauseTimer?.cancel();
        _pauseTimer = Timer(widget.pauseBeforeWelcomeDuration, () {
          if (!mounted) return;

          setState(() {
            _phase = SystemPhase.welcome;
          });
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
            const AuthScreen(initialMode: AuthMode.signIn),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C10),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                // Camera clearance space at the top
                const SizedBox(height: 28),

                // Center Stage: Only Ring + LOCKSYNC or Welcome view
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

  // Orchestrates the display between Ring view and Welcome view
  Widget _buildCenterStage() {
    if (_phase == SystemPhase.welcome) {
      // Welcome view appears after 1.5s delay following ring fade out
      return FadeTransition(
        opacity: _welcomeFadeAnimation,
        child: _buildWelcomeContent(),
      );
    }

    if (_phase == SystemPhase.paused) {
      // During the 1.5s pause, ring has faded out and screen is clean
      return const SizedBox.shrink();
    }

    // Checking, ringExiting, or offline:
    // Shows only the circular ring progress bar with LOCKSYNC in the center
    return FadeTransition(
      opacity: _ringFadeAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular ring progress bar with LOCKSYNC dead center
          _buildProgressRingWithBrand(),

          // If offline: show offline diagnostics and retry controls
          if (_phase == SystemPhase.offline) ...[
            const SizedBox(height: 36),
            _buildOfflineControls(),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // RING PROGRESS BAR WITH LOCKSYNC IN THE DEAD CENTER
  // ==========================================
  Widget _buildProgressRingWithBrand() {
    final bool isOffline = _phase == SystemPhase.offline;
    final Color ringColor =
        isOffline ? const Color(0xFFFF4B55) : const Color(0xFF00D4FF);

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0A1017),
        boxShadow: [
          BoxShadow(
            color: ringColor.withOpacity(isOffline ? 0.30 : 0.22),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Background ring track
          const SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 4.0,
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(0xFF131D28),
              ),
            ),
          ),

          // 2. Active animated circular progress ring
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              final double value =
                  isOffline ? 1.0 : _progressAnimation.value;
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

          // 3. LOCKSYNC brand in the DEAD CENTER of the ring
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                ),
                children: [
                  TextSpan(
                    text: 'LOCK',
                    style: TextStyle(color: Color(0xFFF1F5F9)),
                  ),
                  TextSpan(
                    text: 'SYNC',
                    style: TextStyle(color: Color(0xFF00D4FF)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Offline status and action controls (shown only when offline)
  Widget _buildOfflineControls() {
    return Column(
      key: const Key('offline_state'),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4B55).withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFFF4B55).withOpacity(0.4),
            ),
          ),
          child: const Text(
            'CONNECTION FAILED',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Color(0xFFFF4B55),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'SYSTEM OFFLINE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: Color(0xFFF1F5F9),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Cannot reach Locker 01 hardware. Access restricted until hardware comes online.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            color: Color(0xFF8E9EB2),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        // Retry Connection Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('retry_connection_button'),
            onPressed: _retryConnection,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'RETRY CONNECTION',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: const Color(0xFF080C10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Back to Sign In Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            key: const Key('back_to_sign_in_button'),
            onPressed: _returnToSignIn,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8E9EB2),
              side: const BorderSide(color: Color(0xFF162232), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'BACK TO SIGN IN',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
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

  // ==========================================
  // WELCOME CONTENT (APPEARS AFTER RING FADES & 1.0S PAUSE, HOLDS FOR 1.5S)
  // ==========================================
  Widget _buildWelcomeContent() {
    return const Center(
      key: Key('online_verified_state'),
      child: Text(
        'WELCOME TO LOCKSYNC',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.2,
          color: Color(0xFFF1F5F9),
        ),
      ),
    );
  }
}
