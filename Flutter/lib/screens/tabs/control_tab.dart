import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:locksyncie/models/command_action.dart';
import '../../constants/app_constants.dart';
import '../../services/system_status_service.dart';
import '../../widgets/app_toast.dart';

class ControlTab extends StatefulWidget {
  const ControlTab({super.key});

  @override
  State<ControlTab> createState() => _ControlTabState();
}

class _ControlTabState extends State<ControlTab> {
  static const Duration _commandTimeoutDuration = Duration(seconds: 4);

  final DatabaseReference _lockStatusRef = FirebaseDatabase.instance.ref(
    'lockers/locker_01/status/isLocked',
  );

  final DatabaseReference _commandActionRef = FirebaseDatabase.instance.ref(
    'lockers/locker_01/command/action',
  );

  final SystemStatusService _systemStatusService = SystemStatusService.instance;

  StreamSubscription<DatabaseEvent>? _statusSubscription;
  Timer? _commandTimeoutTimer;

  bool _isLocked = true;
  bool _isLoading = true;
  bool _isPending = false;

  @override
  void initState() {
    super.initState();
    _subscribeToLockStatus();
  }

  @override
  void reassemble() {
    super.reassemble();
    _commandTimeoutTimer?.cancel();
    _isPending = false;
  }

  void _subscribeToLockStatus() {
    _statusSubscription = _lockStatusRef.onValue.listen((event) {
      if (!mounted) return;

      final value = event.snapshot.value;
      _commandTimeoutTimer?.cancel();

      setState(() {
        if (value != null && value is bool) {
          _isLocked = value;
        }

        _isLoading = false;
        _isPending = false;
      });
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _commandTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleLockState(bool isReachable) async {
    if (_isPending || _isLoading || !isReachable) return;

    HapticFeedback.mediumImpact();

    setState(() => _isPending = true);

    final action = _isLocked ? CommandAction.unlock : CommandAction.lock;

    try {
      await _commandActionRef.set(action.value);

      _commandTimeoutTimer?.cancel();
      _commandTimeoutTimer = Timer(
        _commandTimeoutDuration,
        _handleCommandTimeout,
      );
    } catch (_) {
      _handleCommandTimeout();
    }
  }

  void _handleCommandTimeout() {
    if (!mounted || !_isPending) return;

    setState(() => _isPending = false);

    _commandActionRef.set(CommandAction.idle.value);

    AppToast.show(
      context,
      'Command timed out. Lock terminal did not respond.',
      isError: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _systemStatusService.isReachableNotifier,
      builder: (context, isReachable, _) {
        final isUnreachable = !isReachable;
        final showSpinner = _isLoading || _isPending;
        final isInteractive = !showSpinner && isReachable;

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48.0, // Accounts for vertical padding
                ),
                child: Center(
                  child: Bounceable(
                    scaleFactor: 0.72,
                    onTap: isInteractive ? () => _toggleLockState(isReachable) : null,
                    child: AnimatedOpacity(
                      duration: AppDimensions.animDurationStandard,
                      opacity: showSpinner ? 0.65 : 1.0,
                      child: _buildLockIndicator(
                        isLocked: _isLocked,
                        isLoading: showSpinner,
                        isUnreachable: isUnreachable,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLockIndicator({
    required bool isLocked,
    required bool isLoading,
    required bool isUnreachable,
  }) {
    final activeColor = isUnreachable
        ? AppColors.textMuted
        : (isLocked ? AppColors.cyanAccent : AppColors.successGreen);

    return AnimatedContainer(
      duration: AppDimensions.animDurationStandard,
      curve: Curves.easeInOut,
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUnreachable
            ? AppColors.cardBackground.withValues(alpha: 0.4)
            : AppColors.cardBackground,
        border: Border.all(
          color: activeColor.withValues(alpha: isUnreachable ? 0.25 : 0.8),
          width: 2.5,
        ),
        boxShadow: isUnreachable
            ? []
            : [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.3),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
              ],
      ),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background.withValues(
            alpha: isUnreachable ? 0.3 : 0.6,
          ),
          border: Border.all(
            color: activeColor.withValues(alpha: isUnreachable ? 0.12 : 0.25),
            width: 1.5,
          ),
        ),
        child: AnimatedSwitcher(
          duration: AppDimensions.animDurationFast,
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: isLoading
              ? _buildLoadingState(activeColor)
              : _buildStatusContent(
                  key: ValueKey<String>(
                    'content_${isLocked}_$isUnreachable',
                  ),
                  isLocked: isLocked,
                  activeColor: activeColor,
                  isUnreachable: isUnreachable,
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(Color activeColor) {
    final String statusLabel = _isLoading
        ? "CONNECTING..."
        : (_isLocked ? "UNLOCKING..." : "LOCKING...");

    return Column(
      key: const ValueKey<String>('loading_state'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3.0,
            color: activeColor,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: AppDimensions.animDurationFast,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: Text(
            statusLabel,
            key: ValueKey<String>(statusLabel),
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: activeColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "PLEASE WAIT",
          style: TextStyle(
            fontFamily: AppTextStyles.fontSans,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textSubtle.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusContent({
    Key? key,
    required bool isLocked,
    required Color activeColor,
    required bool isUnreachable,
  }) {
    final subtitleText = isUnreachable
        ? "TERMINAL OFFLINE"
        : (isLocked ? "TAP TO UNLOCK" : "TAP TO LOCK");

    final titleText = isLocked ? "LOCKED" : "UNLOCKED";

    return Column(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: AppDimensions.animDurationFast,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: Icon(
            isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            key: ValueKey<bool>(isLocked),
            size: 48,
            color: activeColor,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: AppDimensions.animDurationFast,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: Text(
            titleText,
            key: ValueKey<String>(titleText),
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: activeColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: AppDimensions.animDurationFast,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: Text(
            subtitleText,
            key: ValueKey<String>(subtitleText),
            style: TextStyle(
              fontFamily: AppTextStyles.fontSans,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isUnreachable
                  ? AppColors.textMuted.withValues(alpha: 0.7)
                  : AppColors.textSubtle.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}