import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/lock_model.dart';
import '../../services/lock_service.dart';
import '../../widgets/lock_control_dialogs.dart';

class LockTab extends StatefulWidget {
  final LockDevice? device;
  final void Function(String message, {bool isError}) onShowSnackBar;

  const LockTab({
    super.key,
    required this.device,
    required this.onShowSnackBar,
  });

  @override
  State<LockTab> createState() => _LockTabState();
}

class _LockTabState extends State<LockTab>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _toggleLockState() async {
    final device = widget.device;
    if (_isProcessing || device == null) return;

    // Captured up front so feedback still shows if the user leaves the tab.
    final showSnackBar = widget.onShowSnackBar;
    setState(() => _isProcessing = true);

    try {
      _animController.forward().then((_) {
        if (mounted) _animController.reverse();
      });

      final wasLocked = device.isLocked;
      final success = await LockService.instance.toggleLock(wasLocked);

      if (success) {
        showSnackBar(
          !wasLocked ? 'ARDUINO: LOCK ENGAGED' : 'ARDUINO: LOCK RELEASED',
        );
      } else {
        showSnackBar('Failed to communicate with locker', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _disarmUnauthorizedAttempt() async {
    if (_isProcessing) return;

    final showSnackBar = widget.onShowSnackBar;
    setState(() => _isProcessing = true);

    try {
      final success = await LockService.instance.disarmUnauthorizedAttempt();

      if (success) {
        showSnackBar('SECURITY ALERT DISARMED');
      } else {
        showSnackBar('Failed to disarm security alert', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRenameDialog() {
    showDialog(
      context: context,
      builder: (_) => DeviceRenameDialog(
        currentName: widget.device?.name ?? 'LOCKER 01',
        onRenamed: () => widget.onShowSnackBar('Device renamed successfully'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final isLocked = device?.isLocked ?? true;
    final deviceName = device?.name ?? 'LOCKER 01';
    final hasUnauthorizedAttempt = device?.unauthorizedAttempt ?? false;
    final hasMotion = device?.motionDetected ?? false;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasUnauthorizedAttempt) ...[
            _buildAlertBanner(),
            const SizedBox(height: 16),
          ],

          // Locker Identity Header
          const Text(
            'CONNECTED DEVICE',
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: AppColors.textSubtle,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(deviceName, style: AppTextStyles.heading),
              const SizedBox(width: 6),
              InkWell(
                onTap: _showRenameDialog,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.cyanAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Arduino Smart Lock • ID: ${device?.ID ?? "locker_01"}',
            style: AppTextStyles.subtitle,
          ),

          const SizedBox(height: 28),

          Center(
            child: _buildLockCircle(
              isLocked: isLocked,
              hasUnauthorizedAttempt: hasUnauthorizedAttempt,
            ),
          ),

          const SizedBox(height: 28),

          _buildTelemetryPanel(
            hasMotion: hasMotion,
            isOnline: device != null,
            hasUnauthorizedAttempt: hasUnauthorizedAttempt,
          ),

          const SizedBox(height: 22),

          // Primary Lock Action Button
          SizedBox(
            width: double.infinity,
            height: AppDimensions.primaryButtonHeight,
            child: ElevatedButton(
              key: const Key('primary_biometric_button'),
              onPressed: _toggleLockState,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: AppColors.background,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                    size: 19,
                    color: AppColors.background,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isLocked ? 'UNLOCK TERMINAL' : 'LOCK DEVICE',
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: AppColors.background,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.errorRed, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.errorRed,
            size: 22,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UNAUTHORIZED ACCESS ATTEMPT',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.errorRed,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tamper sensors detected an unauthorized physical entry attempt.',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontSans,
                    fontSize: 11,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _disarmUnauthorizedAttempt,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.errorRed,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              child: const Text(
                'DISARM',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockCircle({
    required bool isLocked,
    required bool hasUnauthorizedAttempt,
  }) {
    return GestureDetector(
      key: const Key('main_lock_circle_button'),
      onTap: _toggleLockState,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: 224,
          height: 224,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.background,
            border: Border.all(
              color: hasUnauthorizedAttempt
                  ? AppColors.errorRed
                  : AppColors.borderDivider,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (hasUnauthorizedAttempt
                        ? AppColors.errorRed
                        : AppColors.cyanAccent)
                    .withValues(alpha: isLocked ? 0.16 : 0.32),
                blurRadius: isLocked ? 38 : 46,
                spreadRadius: isLocked ? 2 : 4,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: 206,
                height: 206,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasUnauthorizedAttempt
                        ? AppColors.errorRed
                        : (isLocked
                            ? AppColors.cyanAccent.withValues(alpha: 0.55)
                            : AppColors.cyanAccent),
                    width: isLocked ? 1.5 : 2.0,
                  ),
                ),
              ),
              Container(
                width: 174,
                height: 174,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderSubtle, width: 1.0),
                ),
              ),
              Container(
                width: 152,
                height: 152,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cardBackground,
                  border: Border.all(color: AppColors.borderInput, width: 1.0),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        isLocked
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        key: ValueKey<bool>(isLocked),
                        size: 44,
                        color: hasUnauthorizedAttempt
                            ? AppColors.errorRed
                            : AppColors.cyanAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLocked ? 'LOCKED' : 'UNLOCKED',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontMono,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                        color: hasUnauthorizedAttempt
                            ? AppColors.errorRed
                            : (isLocked
                                ? AppColors.textPrimary
                                : AppColors.cyanAccent),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLocked ? 'TAP TO UNLOCK' : 'TAP TO LOCK',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontMono,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                        color: isLocked
                            ? AppColors.textSubtle
                            : AppColors.cyanAccent.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryPanel({
    required bool hasMotion,
    required bool isOnline,
    required bool hasUnauthorizedAttempt,
  }) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatusColumn(
              label: 'MOTION',
              icon: Icons.sensors_rounded,
              value: hasMotion ? 'ACTIVE' : 'STILL',
              valueColor:
                  hasMotion ? AppColors.cyanAccent : AppColors.textPrimary,
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.borderSubtle),
          Expanded(
            child: _buildStatusColumn(
              label: 'DEVICE',
              icon: Icons.developer_board_rounded,
              value: isOnline ? 'ONLINE' : 'CONNECTING',
              valueColor:
                  isOnline ? AppColors.cyanAccent : AppColors.errorRed,
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.borderSubtle),
          Expanded(
            child: _buildStatusColumn(
              label: 'SECURITY',
              icon: hasUnauthorizedAttempt
                  ? Icons.error_outline_rounded
                  : Icons.security_rounded,
              value: hasUnauthorizedAttempt ? 'ALERT' : 'CLEAR',
              valueColor: hasUnauthorizedAttempt
                  ? AppColors.errorRed
                  : AppColors.cyanAccent,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatusColumn({
    required String label,
    required IconData icon,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: AppColors.textSubtle,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: valueColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: valueColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}