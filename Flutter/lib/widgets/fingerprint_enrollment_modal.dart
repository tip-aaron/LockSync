import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/lock_model.dart';
import '../services/lock_service.dart';
import 'locksync_text_field.dart';

/// Interactive modal for guiding user and hardware through ES608 biometric fingerprint enrollment.
///
/// [initialCount] seeds the registered-slot count so a full sensor is shown
/// as full on the first frame, before the live stream emits.
void showFingerprintEnrollmentModal(
  BuildContext context, {
  int initialCount = 0,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => FingerprintEnrollmentModal(initialCount: initialCount),
  );
}

class FingerprintEnrollmentModal extends StatefulWidget {
  final int initialCount;

  const FingerprintEnrollmentModal({super.key, this.initialCount = 0});

  @override
  State<FingerprintEnrollmentModal> createState() =>
      _FingerprintEnrollmentModalState();
}

class _FingerprintEnrollmentModalState extends State<FingerprintEnrollmentModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _labelController = TextEditingController(
    text: 'Right Thumb',
  );
  final LockService _lockService = LockService.instance;

  StreamSubscription<LockDevice?>? _lockSub;
  EnrollStatus _status = EnrollStatus.IDLE;
  String _lastAction = 'READY';
  late int _currentFingerprintCount;

  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  bool _isStarted = false;
  bool _isClosing = false; // Guard flag to prevent re-entrant modal pops

  // History session for the current enrollment attempt (null when none open).
  String? _sessionId;
  int _countAtStart = 0;

  bool get _isCapacityFull =>
      _currentFingerprintCount >= SensorLimits.maxFingerprintSlots;

  /// True while the hardware is mid-enrollment or has just finished one.
  /// The sensor filling up during these states is expected, not an error.
  bool get _isEnrollmentActiveOrDone =>
      _status == EnrollStatus.START_ENROLL ||
      _status == EnrollStatus.PLACE_FINGER_1 ||
      _status == EnrollStatus.REMOVE_FINGER ||
      _status == EnrollStatus.PLACE_FINGER_2 ||
      _status == EnrollStatus.PROCESSING ||
      _status == EnrollStatus.COMPLETED;

  /// Show the "sensor full" state only when no enrollment is running or done.
  bool get _showCapacityFull => _isCapacityFull && !_isEnrollmentActiveOrDone;

  bool get _isErrorState =>
      _status == EnrollStatus.ERROR_PRINTS_DONT_MATCH ||
      _status == EnrollStatus.ERROR_STORAGE_FAILED ||
      _status == EnrollStatus.ERROR_SCAN_FAILED ||
      _status == EnrollStatus.TIMEOUT;

  bool _isTerminal(EnrollStatus s) =>
      s == EnrollStatus.COMPLETED ||
      s == EnrollStatus.ERROR_PRINTS_DONT_MATCH ||
      s == EnrollStatus.ERROR_STORAGE_FAILED ||
      s == EnrollStatus.ERROR_SCAN_FAILED ||
      s == EnrollStatus.TIMEOUT;

  /// START_ENROLL is written by the service when the session opens;
  /// IDLE / UNKNOWN are not real enrollment steps.
  bool _isLoggable(EnrollStatus s) =>
      s != EnrollStatus.IDLE &&
      s != EnrollStatus.UNKNOWN &&
      s != EnrollStatus.START_ENROLL;

  @override
  void initState() {
    super.initState();
    _currentFingerprintCount = widget.initialCount;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _lockSub = _lockService.streamLock().listen((device) {
      if (!mounted || device == null) return;

      final previous = _status;
      final next = device.enrollStatus;
      final slots = device.registeredSlots.values.toList();

      setState(() {
        _status = next;
        _lastAction = device.lastAction;
        _currentFingerprintCount = slots.length;
      });

      // Append each status transition to this attempt's history session.
      // Only runs for a session this modal opened, so a stale status left on
      // the device from an earlier run is never logged.
      final sessionId = _sessionId;
      if (sessionId == null || previous == next || !_isLoggable(next)) return;

      int? slotID;
      if (next == EnrollStatus.COMPLETED && slots.length > _countAtStart) {
        slots.sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
        slotID = slots.first.slotID;
      }

      _lockService.logEnrollmentEvent(sessionId, next, slotID: slotID);

      // Attempt finished; a retry opens a new session.
      if (_isTerminal(next)) _sessionId = null;
    });
  }

  @override
  void dispose() {
    _lockSub?.cancel();
    _animController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    if (_isCapacityFull) return;

    final sessionId = _lockService.newEnrollmentSessionId();
    if (sessionId == null) return;

    final label = _labelController.text.trim().isNotEmpty
        ? _labelController.text.trim()
        : 'Fingerprint';

    setState(() {
      _isStarted = true;
      _sessionId = sessionId;
      _countAtStart = _currentFingerprintCount;
    });

    await _lockService.startEnrollment(sessionId: sessionId, label: label);
  }

  void _closeAndReset() {
    if (_isClosing) return;
    _isClosing = true;

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;

        // A session still open here means the attempt never reached COMPLETED
        // or an error, so the user abandoned it.
        final sessionId = _sessionId;
        if (sessionId != null) {
          _sessionId = null;
          _lockService.logEnrollmentEvent(sessionId, EnrollStatus.CANCELED);
        }

        _lockService.finalizeOrResetWorkflow();
      },
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + keyboardPadding),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusCircular),
          ),
          border: Border.all(color: AppColors.borderDivider, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Drag Handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Header Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BIOMETRIC ENROLLMENT',
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontMono,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ES608 Module ($_currentFingerprintCount/${SensorLimits.maxFingerprintSlots} Capacity)',
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontSans,
                            fontSize: 12,
                            color: _isCapacityFull
                                ? AppColors.errorRed
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      key: const Key('close_enrollment_modal_button'),
                      onPressed: _closeAndReset,
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textSecondary,
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const Divider(color: AppColors.borderSubtle, height: 26),

                // 3. Step Progress Tracker
                _buildStepTracker(),
                const SizedBox(height: 24),

                // 4. Central Animated Scanner Visual
                _buildScannerVisual(),
                const SizedBox(height: 20),

                // 5. Dynamic Guidance Text
                _buildGuidanceText(),
                const SizedBox(height: 24),

                // 6. Label Input Field (only before start and if slots available)
                if (!_isStarted &&
                    _status == EnrollStatus.IDLE &&
                    !_isCapacityFull) ...[
                  LockSyncTextField(
                    label: 'FINGERPRINT LABEL',
                    placeholder: 'e.g. Right Index, Left Thumb',
                    prefixIcon: Icons.label_outlined,
                    controller: _labelController,
                    maxLength: 30,
                  ),
                  const SizedBox(height: 20),
                ],

                // 7. Action Button Panel
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepTracker() {
    int activeStep = 0;
    if (_status == EnrollStatus.START_ENROLL ||
        _status == EnrollStatus.PLACE_FINGER_1) {
      activeStep = 1;
    } else if (_status == EnrollStatus.REMOVE_FINGER) {
      activeStep = 2;
    } else if (_status == EnrollStatus.PLACE_FINGER_2) {
      activeStep = 3;
    } else if (_status == EnrollStatus.PROCESSING) {
      activeStep = 4;
    } else if (_status == EnrollStatus.COMPLETED) {
      activeStep = 5;
    }

    const steps = ['Init', 'Scan 1', 'Lift', 'Scan 2', 'Process', 'Done'];

    return Row(
      children: List.generate(steps.length, (i) {
        final isPassed = activeStep > i;
        final isCurrent = activeStep == i;
        final stepColor = isPassed || isCurrent
            ? AppColors.cyanAccent
            : AppColors.borderSubtle;

        return Expanded(
          child: Column(
            children: [
              Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: stepColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.cyanAccent.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                steps[i],
                style: TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 9,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent
                      ? AppColors.cyanAccent
                      : AppColors.textSubtle,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildScannerVisual() {
    Color ringColor = AppColors.cyanAccent;
    IconData centerIcon = Icons.fingerprint_rounded;

    if (_showCapacityFull) {
      ringColor = AppColors.errorRed;
      centerIcon = Icons.warning_amber_rounded;
    } else if (_isErrorState) {
      ringColor = AppColors.errorRed;
      centerIcon = Icons.error_outline_rounded;
    } else if (_status == EnrollStatus.COMPLETED) {
      ringColor = const Color(0xFF00E676);
      centerIcon = Icons.check_circle_outline_rounded;
    } else if (_status == EnrollStatus.REMOVE_FINGER) {
      ringColor = const Color(0xFFFFB300);
      centerIcon = Icons.arrow_upward_rounded;
    }

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background,
          border: Border.all(
            color: ringColor.withValues(alpha: 0.4),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: ringColor.withValues(alpha: 0.18),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 114,
              height: 114,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ringColor.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
            ),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cardBackground,
                border: Border.all(color: AppColors.borderSubtle, width: 1.0),
              ),
              child: Center(
                child: Icon(centerIcon, size: 44, color: ringColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceText() {
    String headline;
    String description;
    Color headlineColor = AppColors.textPrimary;

    if (_showCapacityFull) {
      headline = 'SENSOR MEMORY FULL';
      description =
          'All ${SensorLimits.maxFingerprintSlots} fingerprint slots are currently assigned. Delete a registered fingerprint to free up slot space.';
      headlineColor = AppColors.errorRed;
    } else {
      switch (_status) {
        case EnrollStatus.CANCELED:
          headline = 'ENROLLMENT CANCELED';
          description = 'This enrollment was canceled before it finished.';
          headlineColor = AppColors.textSecondary;
        case EnrollStatus.IDLE:
          headline = 'BIOMETRIC REGISTRATION';
          description =
              'Register a new finger on the optical sensor. Follow the 2-step verification prompts.';
        case EnrollStatus.START_ENROLL:
          headline = 'COMMUNICATING WITH ESP32';
          description =
              'Searching for an available hardware template slot (1–${SensorLimits.maxFingerprintSlots}) on the locker module...';
          headlineColor = AppColors.cyanAccent;
        case EnrollStatus.PLACE_FINGER_1:
          headline = 'SCAN 1: PLACE FINGER';
          description =
              'Press your finger firmly and flat onto the sensor surface.';
          headlineColor = AppColors.cyanAccent;
        case EnrollStatus.REMOVE_FINGER:
          headline = 'FIRST SCAN CAPTURED';
          description =
              'Lift your finger from the sensor and wait for the second scan prompt.';
          headlineColor = const Color(0xFFFFB300);
        case EnrollStatus.PLACE_FINGER_2:
          headline = 'SCAN 2: PLACE SAME FINGER';
          description =
              'Place the same finger again to confirm fingerprint minutiae.';
          headlineColor = AppColors.cyanAccent;
        case EnrollStatus.PROCESSING:
          headline = 'GENERATING BIOMETRIC MODEL';
          description =
              'Converting optical minutiae into a secure cryptographic template...';
          headlineColor = AppColors.cyanAccent;
        case EnrollStatus.COMPLETED:
          headline = 'ENROLLMENT COMPLETED!';
          description =
              'Template successfully stored in flash memory and synced with Firebase.';
          headlineColor = const Color(0xFF00E676);
        case EnrollStatus.ERROR_PRINTS_DONT_MATCH:
          headline = 'PRINTS DO NOT MATCH';
          description =
              'The second scan differed from the first. Please restart the enrollment.';
          headlineColor = AppColors.errorRed;
        case EnrollStatus.ERROR_STORAGE_FAILED:
          headline = 'STORAGE FAILED';
          description =
              'Unable to write print template to hardware flash memory.';
          headlineColor = AppColors.errorRed;
        case EnrollStatus.ERROR_SCAN_FAILED:
        case EnrollStatus.TIMEOUT:
          headline = 'SCAN TIMEOUT / ERROR';
          description =
              'Could not complete scanning. Ensure the sensor glass is clear and dry.';
          headlineColor = AppColors.errorRed;
        case EnrollStatus.UNKNOWN:
          headline = 'UNKNOWN HARDWARE STATE';
          description =
              'An unexpected state response was received from the hardware.';
          headlineColor = AppColors.textSecondary;
      }
    }

    return Column(
      children: [
        Text(
          headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: headlineColor,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTextStyles.fontSans,
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
        if (_lastAction != 'READY') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              'ACTION: $_lastAction',
              style: const TextStyle(
                fontFamily: AppTextStyles.fontMono,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.cyanAccent,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_showCapacityFull) {
      return SizedBox(
        width: double.infinity,
        height: AppDimensions.secondaryButtonHeight,
        child: OutlinedButton(
          key: const Key('close_full_sensor_button'),
          onPressed: _closeAndReset,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.borderSubtle),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
          ),
          child: const Text(
            'CLOSE',
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (_status == EnrollStatus.COMPLETED) {
      return SizedBox(
        width: double.infinity,
        height: AppDimensions.secondaryButtonHeight,
        child: ElevatedButton(
          key: const Key('enrollment_done_button'),
          onPressed: _closeAndReset,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cyanAccent,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            elevation: 0,
          ),
          child: const Text('DONE', style: AppTextStyles.buttonLabel),
        ),
      );
    }

    if (_isErrorState) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('cancel_after_error_button'),
              onPressed: _closeAndReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.borderSubtle),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              key: const Key('retry_enrollment_button'),
              onPressed: _startEnrollment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!_isStarted) {
      return SizedBox(
        width: double.infinity,
        height: AppDimensions.secondaryButtonHeight,
        child: ElevatedButton(
          key: const Key('start_enrollment_button'),
          onPressed: _startEnrollment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cyanAccent,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fingerprint_rounded, size: 20),
              SizedBox(width: 8),
              Text('START ENROLLMENT', style: AppTextStyles.buttonLabel),
            ],
          ),
        ),
      );
    }

    // Ongoing enrollment state - offers active cancellation
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.secondaryButtonHeight,
      child: OutlinedButton(
        key: const Key('cancel_enrollment_button'),
        onPressed: _closeAndReset,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.errorRed,
          side: const BorderSide(color: AppColors.errorBackground),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
        ),
        child: const Text(
          'CANCEL ENROLLMENT',
          style: TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
