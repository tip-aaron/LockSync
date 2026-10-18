import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lock_model.dart';
import '../services/lock_service.dart';

/// Interactive modal for guiding user and hardware through ES608 biometric fingerprint enrollment.
void showFingerprintEnrollmentModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const FingerprintEnrollmentModal(),
  );
}

class FingerprintEnrollmentModal extends StatefulWidget {
  const FingerprintEnrollmentModal({super.key});

  @override
  State<FingerprintEnrollmentModal> createState() =>
      _FingerprintEnrollmentModalState();
}

class _FingerprintEnrollmentModalState extends State<FingerprintEnrollmentModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _labelController =
      TextEditingController(text: 'Right Thumb');
  final LockService _lockService = LockService.instance;

  StreamSubscription<EnrollmentTelemetry>? _enrollSub;
  EnrollmentTelemetry _telemetry = const EnrollmentTelemetry(
    status: EnrollStatus.idle,
    lastAction: 'READY',
  );

  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  bool _isStarted = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _enrollSub = _lockService.streamEnrollment().listen((telemetry) {
      if (mounted) {
        setState(() {
          _telemetry = telemetry;
        });
      }
    });
  }

  @override
  void dispose() {
    _enrollSub?.cancel();
    _animController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollment() async {
    setState(() {
      _isStarted = true;
    });
    final label = _labelController.text.trim().isNotEmpty
        ? _labelController.text.trim()
        : 'Fingerprint 1';
    await _lockService.startEnrollment(label: label);
  }

  Future<void> _closeAndReset() async {
    await _lockService.finalizeOrResetWorkflow();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final status = _telemetry.status;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + keyboardPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF090E16),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF162536), width: 1.5),
          left: BorderSide(color: Color(0xFF162536), width: 1.0),
          right: BorderSide(color: Color(0xFF162536), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 32,
            offset: Offset(0, -8),
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
                  color: const Color(0xFF22354A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Header with Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'BIOMETRIC ENROLLMENT',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          color: Color(0xFFF1F5F9),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'ES608 Optical Sensor Module',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF7A889B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    key: const Key('close_enrollment_modal_button'),
                    onPressed: _closeAndReset,
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF7A889B),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const Divider(color: Color(0xFF162232), height: 26),

              // 3. Step Progress Indicators
              _buildStepTracker(status),
              const SizedBox(height: 24),

              // 4. Central Animated Scanner Graphic
              _buildScannerVisual(status),
              const SizedBox(height: 20),

              // 5. Dynamic Guidance Text
              _buildGuidanceText(status),
              const SizedBox(height: 24),

              // 6. Label Input (Visible before starting)
              if (!_isStarted && status == EnrollStatus.idle) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'FINGERPRINT LABEL',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Color(0xFF7A889B),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D141F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E2E42)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    key: const Key('fingerprint_label_input'),
                    controller: _labelController,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFFF1F5F9),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'e.g. Right Index, Left Thumb',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF4A5C70),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 7. Action Button Panel
              _buildActionButtons(status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepTracker(EnrollStatus status) {
    int activeStep = 0;
    if (status == EnrollStatus.startEnroll ||
        status == EnrollStatus.placeFinger1) {
      activeStep = 1;
    } else if (status == EnrollStatus.removeFinger) {
      activeStep = 2;
    } else if (status == EnrollStatus.placeFinger2) {
      activeStep = 3;
    } else if (status == EnrollStatus.processing) {
      activeStep = 4;
    } else if (status == EnrollStatus.completed) {
      activeStep = 5;
    }

    final steps = ['Init', 'Scan 1', 'Lift', 'Scan 2', 'Process', 'Done'];

    return Row(
      children: List.generate(steps.length, (i) {
        final isPassed = activeStep > i;
        final isCurrent = activeStep == i;
        final stepColor = isPassed || isCurrent
            ? const Color(0xFF00D4FF)
            : const Color(0xFF22354A);

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
                            color: const Color(0xFF00D4FF).withOpacity(0.5),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                steps[i],
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent
                      ? const Color(0xFF00D4FF)
                      : const Color(0xFF5A6B80),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildScannerVisual(EnrollStatus status) {
    Color ringColor = const Color(0xFF00D4FF);
    IconData centerIcon = Icons.fingerprint_rounded;
    bool isError = status.isError;

    if (isError) {
      ringColor = const Color(0xFFFF5252);
      centerIcon = Icons.error_outline_rounded;
    } else if (status == EnrollStatus.completed) {
      ringColor = const Color(0xFF00E676);
      centerIcon = Icons.check_circle_outline_rounded;
    } else if (status == EnrollStatus.removeFinger) {
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
          color: const Color(0xFF060A0F),
          border: Border.all(
            color: ringColor.withOpacity(0.4),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: ringColor.withOpacity(0.18),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Inner track
            Container(
              width: 114,
              height: 114,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ringColor.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
            ),
            // Core Disk
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0B1420),
                border: Border.all(
                  color: const Color(0xFF1E2E42),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Icon(
                  centerIcon,
                  size: 44,
                  color: ringColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceText(EnrollStatus status) {
    String headline = 'READY TO ENROLL';
    String description =
        'Ensure the ES608 sensor is clean. You will be prompted to place and lift your finger twice.';
    Color headlineColor = const Color(0xFFF1F5F9);

    switch (status) {
      case EnrollStatus.idle:
        headline = 'BIOMETRIC REGISTRATION';
        description =
            'Register a new finger on the optical sensor. Follow the 2-step verification prompts.';
        break;
      case EnrollStatus.startEnroll:
        headline = 'COMMUNICATING WITH ESP32';
        description =
            'Searching for an available hardware template slot on the locker module...';
        headlineColor = const Color(0xFF00D4FF);
        break;
      case EnrollStatus.placeFinger1:
        headline = 'SCAN 1: PLACE FINGER';
        description =
            'Press your finger firmly and flat onto the sensor surface.';
        headlineColor = const Color(0xFF00D4FF);
        break;
      case EnrollStatus.removeFinger:
        headline = 'FIRST SCAN CAPTURED';
        description =
            'Lift your finger from the sensor and wait for the second scan prompt.';
        headlineColor = const Color(0xFFFFB300);
        break;
      case EnrollStatus.placeFinger2:
        headline = 'SCAN 2: PLACE SAME FINGER';
        description =
            'Place the same finger again to confirm fingerprint minutiae.';
        headlineColor = const Color(0xFF00D4FF);
        break;
      case EnrollStatus.processing:
        headline = 'GENERATING BIOMETRIC MODEL';
        description =
            'Converting optical minutiae into a secure cryptographic template...';
        headlineColor = const Color(0xFF00D4FF);
        break;
      case EnrollStatus.completed:
        headline = 'ENROLLMENT COMPLETED!';
        description =
            'Template successfully stored in flash memory and synced with Firebase.';
        headlineColor = const Color(0xFF00E676);
        break;
      case EnrollStatus.errorPrintsDontMatch:
        headline = 'PRINTS DO NOT MATCH';
        description =
            'The second scan differed from the first. Please restart the enrollment.';
        headlineColor = const Color(0xFFFF5252);
        break;
      case EnrollStatus.errorScanFailed:
      case EnrollStatus.errorTimeout:
        headline = 'SCAN TIMEOUT / ERROR';
        description =
            'Could not complete scanning. Ensure the sensor glass is clear and dry.';
        headlineColor = const Color(0xFFFF5252);
        break;
      case EnrollStatus.unknown:
        break;
    }

    return Column(
      children: [
        Text(
          headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
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
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: Color(0xFF7A889B),
              height: 1.35,
            ),
          ),
        ),
        if (_telemetry.lastAction != null && _telemetry.lastAction != 'READY') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A26),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1E2E42)),
            ),
            child: Text(
              'PAYLOAD: ${_telemetry.lastAction}',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00D4FF),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(EnrollStatus status) {
    if (status == EnrollStatus.completed) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          key: const Key('enrollment_done_button'),
          onPressed: _closeAndReset,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D4FF),
            foregroundColor: const Color(0xFF080C10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: const Text(
            'DONE',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }

    if (status.isError) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _closeAndReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7A889B),
                side: const BorderSide(color: Color(0xFF1E2E42)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _startEnrollment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: const Color(0xFF080C10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
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
        height: 50,
        child: ElevatedButton(
          key: const Key('start_enrollment_button'),
          onPressed: _startEnrollment,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D4FF),
            foregroundColor: const Color(0xFF080C10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fingerprint_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                'START ENROLLMENT',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Ongoing enrollment state
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            key: const Key('cancel_enrollment_button'),
            onPressed: _closeAndReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF5252),
              side: const BorderSide(color: Color(0xFF4A1A22)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'CANCEL ENROLLMENT',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Interactive simulation skip trigger for browser testing
        InkWell(
          key: const Key('simulate_hardware_step_button'),
          onTap: () => _lockService.simulateAdvanceEnrollmentStep(),
          child: const Padding(
            padding: EdgeInsets.all(4.0),
            child: Text(
              '⚡ SIMULATE HARDWARE STEP',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00D4FF),
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
