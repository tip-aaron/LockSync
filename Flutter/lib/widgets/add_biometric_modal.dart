import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:locksyncie/models/command_action.dart';
import '../../constants/app_constants.dart';

// -----------------------------------------------------------------------------
// ENROLLMENT STATUS ENUM
// -----------------------------------------------------------------------------
enum EnrollmentStatus {
  idle(0),
  enrolling(1),
  placeFirstFinger(2),
  placeSecondFinger(3),
  raiseFinger(4),
  success(5),
  failed(6),
  cancelled(7);

  final int value;
  const EnrollmentStatus(this.value);

  static EnrollmentStatus fromDynamic(dynamic raw) {
    if (raw == null) return EnrollmentStatus.idle;

    int? parsedInt;
    if (raw is num) {
      parsedInt = raw.toInt();
    } else {
      parsedInt = int.tryParse(raw.toString().trim());
    }

    if (parsedInt != null) {
      for (final status in EnrollmentStatus.values) {
        if (status.value == parsedInt) return status;
      }
    }

    final str = raw.toString().trim().toUpperCase();
    if (str.contains("FAIL") || str.contains("ERR")) return EnrollmentStatus.failed;
    if (str.contains("CANCEL")) return EnrollmentStatus.cancelled;
    if (str.contains("SUCCESS")) return EnrollmentStatus.success;
    if (str.contains("FIRST")) return EnrollmentStatus.placeFirstFinger;
    if (str.contains("SECOND")) return EnrollmentStatus.placeSecondFinger;
    if (str.contains("RAISE") || str.contains("LIFT")) return EnrollmentStatus.raiseFinger;
    if (str.contains("ENROLL")) return EnrollmentStatus.enrolling;

    return EnrollmentStatus.idle;
  }
}

// -----------------------------------------------------------------------------
// ADD BIOMETRIC MODAL BOTTOM SHEET
// -----------------------------------------------------------------------------
class AddBiometricModal extends StatefulWidget {
  const AddBiometricModal({super.key});

  @override
  State<AddBiometricModal> createState() => _AddBiometricModalState();
}

class _AddBiometricModalState extends State<AddBiometricModal> {
  static const Duration _cancelTimeout = Duration(seconds: 4);
  static const Duration _enrollTimeout = Duration(seconds: 12);

  static const String _statusEnrollmentPath =
      'lockers/locker_01/status/enrollmentStatus';
  static const String _commandActionPath =
      'lockers/locker_01/command/action';
  static const String _commandParamPath =
      'lockers/locker_01/command/param';

  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  StreamSubscription<DatabaseEvent>? _statusSubscription;
  Timer? _enrollTimeoutTimer;

  int _step = 0; // 0: Name Input, 1: Hardware Scanner Workflow
  int _activeSlot = 1;
  EnrollmentStatus _currentStatus = EnrollmentStatus.idle;
  bool _isCancelling = false;
  bool _hasSavedToFirebase = false;

  @override
  void dispose() {
    _enrollTimeoutTimer?.cancel();
    _statusSubscription?.cancel();
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _startEnrollTimeoutTimer() {
    _enrollTimeoutTimer?.cancel();
    _enrollTimeoutTimer = Timer(_enrollTimeout, () {
      if (!mounted) return;
      if (_currentStatus == EnrollmentStatus.enrolling ||
          _currentStatus == EnrollmentStatus.idle) {
        setState(() {
          _currentStatus = EnrollmentStatus.failed;
        });
      }
    });
  }

  Future<int> _findNextAvailableSlot() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('lockers/locker_01/fingerprints')
          .get();

      if (snap.exists && snap.value != null) {
        final Set<int> usedSlots = {};
        final rawData = snap.value;

        if (rawData is Map) {
          rawData.forEach((key, val) {
            if (val != null) {
              final parsedKey = int.tryParse(key.toString());
              if (parsedKey != null) usedSlots.add(parsedKey);
            }
          });
        } else if (rawData is List) {
          for (int i = 0; i < rawData.length; i++) {
            if (rawData[i] != null) {
              usedSlots.add(i);
            }
          }
        }

        for (int i = 1; i <= 162; i++) {
          if (!usedSlots.contains(i)) {
            return i;
          }
        }
      }
    } catch (_) {}
    return 1;
  }  void _listenToEnrollmentStatus() {
    _statusSubscription?.cancel();
    _statusSubscription = FirebaseDatabase.instance
        .ref(_statusEnrollmentPath)
        .onValue
        .listen((event) {
      if (!mounted) return;

      final rawStatus = EnrollmentStatus.fromDynamic(event.snapshot.value);

      // Ignore initial stale IDLE state while waiting for ESP32 to start
      if (_currentStatus == EnrollmentStatus.enrolling &&
          rawStatus == EnrollmentStatus.idle) {
        return;
      }

      // Lock UI on terminal states (SUCCESS, FAILED, CANCELLED)
      if ((_currentStatus == EnrollmentStatus.success ||
              _currentStatus == EnrollmentStatus.failed ||
              _currentStatus == EnrollmentStatus.cancelled) &&
          rawStatus == EnrollmentStatus.idle) {
        return;
      }

      if (rawStatus == EnrollmentStatus.success ||
          rawStatus == EnrollmentStatus.failed ||
          rawStatus == EnrollmentStatus.cancelled ||
          rawStatus == EnrollmentStatus.placeFirstFinger) {
        _enrollTimeoutTimer?.cancel();
      }

      setState(() {
        _currentStatus = rawStatus;
      });

      if (rawStatus == EnrollmentStatus.success && !_hasSavedToFirebase) {
        _saveFingerprintMetadata();
      }
    });
  }

  void _startEnrollmentWorkflow() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _step = 1;
      _currentStatus = EnrollmentStatus.enrolling;
      _hasSavedToFirebase = false;
    });

    _startEnrollTimeoutTimer();
    _listenToEnrollmentStatus();

    final slotId = await _findNextAvailableSlot();
    _activeSlot = slotId;

    await FirebaseDatabase.instance.ref(_commandParamPath).set(slotId);
    await FirebaseDatabase.instance
        .ref(_commandActionPath)
        .set(CommandAction.enrollFingerprint.value);
  }

  Future<void> _saveFingerprintMetadata() async {
    _hasSavedToFirebase = true;

    try {
      final fingerprintsRef =
          FirebaseDatabase.instance.ref('lockers/locker_01/fingerprints');

      final slotSnap = await FirebaseDatabase.instance
          .ref('lockers/locker_01/status/enrolledSlot')
          .get();

      int targetSlot = _activeSlot;

      if (slotSnap.exists && slotSnap.value != null) {
        final parsed = int.tryParse(slotSnap.value.toString());
        if (parsed != null && parsed > 0) {
          targetSlot = parsed;
        }
      }

      await fingerprintsRef.child(targetSlot.toString()).set({
        'name': _nameController.text.trim(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'lastUsed': null,
      });

      await FirebaseDatabase.instance.ref(_commandParamPath).set(0);
      await FirebaseDatabase.instance
          .ref(_commandActionPath)
          .set(CommandAction.idle.value);
    } catch (_) {}
  }

  Future<void> _retryEnrollment() async {
    _enrollTimeoutTimer?.cancel();
    setState(() {
      _currentStatus = EnrollmentStatus.enrolling;
      _hasSavedToFirebase = false;
    });

    _startEnrollTimeoutTimer();
    _listenToEnrollmentStatus();

    final slotId = await _findNextAvailableSlot();
    _activeSlot = slotId;

    await FirebaseDatabase.instance.ref(_commandParamPath).set(slotId);
    await FirebaseDatabase.instance
        .ref(_commandActionPath)
        .set(CommandAction.enrollFingerprint.value);
  }

  Future<void> _cancelAndClose() async {
    if (_isCancelling) return;

    _enrollTimeoutTimer?.cancel();

    if (_step == 1 &&
        _currentStatus != EnrollmentStatus.success &&
        _currentStatus != EnrollmentStatus.idle) {
      setState(() => _isCancelling = true);

      try {
        await FirebaseDatabase.instance
            .ref(_commandActionPath)
            .set(CommandAction.cancelEnrollment.value);

        final Completer<void> cancelCompleter = Completer<void>();
        Timer? timeoutTimer;
        StreamSubscription<DatabaseEvent>? cancelSub;

        cancelSub = FirebaseDatabase.instance
            .ref(_statusEnrollmentPath)
            .onValue
            .listen((event) {
          final status = EnrollmentStatus.fromDynamic(event.snapshot.value);
          if (status == EnrollmentStatus.idle ||
              status == EnrollmentStatus.cancelled) {
            if (!cancelCompleter.isCompleted) {
              cancelCompleter.complete();
            }
          }
        });

        timeoutTimer = Timer(_cancelTimeout, () async {
          if (!cancelCompleter.isCompleted) {
            try {
              await FirebaseDatabase.instance
                  .ref(_statusEnrollmentPath)
                  .set(EnrollmentStatus.idle.value);
            } catch (_) {}
            cancelCompleter.complete();
          }
        });

        await cancelCompleter.future;
        timeoutTimer.cancel();
        await cancelSub.cancel();

        await FirebaseDatabase.instance.ref(_commandParamPath).set(0);
        await FirebaseDatabase.instance
            .ref(_commandActionPath)
            .set(CommandAction.idle.value);
      } catch (_) {
        await FirebaseDatabase.instance.ref(_commandParamPath).set(0);
        await FirebaseDatabase.instance
            .ref(_commandActionPath)
            .set(CommandAction.idle.value);
      }
    } else {
      try {
        await FirebaseDatabase.instance.ref(_commandParamPath).set(0);
        await FirebaseDatabase.instance
            .ref(_commandActionPath)
            .set(CommandAction.idle.value);
      } catch (_) {}
    }

    _statusSubscription?.cancel();
    _nameController.clear();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancelAndClose();
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0 + bottomInset),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusLarge),
          ),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: const [
                Icon(
                  Icons.fingerprint_rounded,
                  color: AppColors.cyanAccent,
                  size: 22,
                ),
                SizedBox(width: 10),
                Text(
                  "FINGERPRINT REGISTRATION",
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyanAccent,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "Register a fingerprint to be used for your smart locker",
              style: TextStyle(
                fontFamily: AppTextStyles.fontSans,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: AppDimensions.animDurationStandard,
              child: _step == 0 ? _buildNameInputStep() : _buildScannerStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameInputStep() {
    return Column(
      key: const ValueKey<int>(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "FINGERPRINT NAME",
          style: TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textSubtle,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          autofocus: true,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontSans,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: "e.g., Right Index Finger",
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontFamily: AppTextStyles.fontSans,
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              borderSide: const BorderSide(color: AppColors.cyanAccent),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _cancelAndClose,
                child: const Text(
                  "CANCEL",
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                  ),
                ),
                onPressed: _nameController.text.trim().isNotEmpty
                    ? _startEnrollmentWorkflow
                    : null,
                child: const Text(
                  "NEXT",
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LAYOUT 2: HARDWARE SCANNER WORKFLOW STEP
  // ---------------------------------------------------------------------------
  Widget _buildScannerStep() {
    final bool isSuccess = _currentStatus == EnrollmentStatus.success;
    final bool isFailed = _currentStatus == EnrollmentStatus.failed ||
        _currentStatus == EnrollmentStatus.cancelled;
    final bool isProcessing = _currentStatus == EnrollmentStatus.enrolling ||
        _currentStatus == EnrollmentStatus.idle ||
        _isCancelling;

    final Color statusColor = isSuccess
        ? AppColors.successGreen
        : isFailed
            ? AppColors.errorRed
            : AppColors.cyanAccent;

    // Calculate progress fill percentage (0.0 to 1.0) or null for indeterminate
    double? progressValue;
    if (_isCancelling ||
        _currentStatus == EnrollmentStatus.enrolling ||
        _currentStatus == EnrollmentStatus.idle) {
      progressValue = null; // Indeterminate spinning border
    } else {
      switch (_currentStatus) {
        case EnrollmentStatus.placeFirstFinger:
          progressValue = 0.25;
          break;
        case EnrollmentStatus.raiseFinger:
          progressValue = 0.50;
          break;
        case EnrollmentStatus.placeSecondFinger:
          progressValue = 0.75;
          break;
        case EnrollmentStatus.success:
        case EnrollmentStatus.failed:
        case EnrollmentStatus.cancelled:
          progressValue = 1.0;
          break;
        default:
          progressValue = 0.0;
      }
    }

    return Column(
      key: const ValueKey<int>(1),
      children: [
        // BIG CIRCLE CONTAINER WITH ANIMATED OUTER PROGRESS RING
        Center(
          child: SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Ambient Glow
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // 2. Background Track Ring
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 4.0,
                    color: statusColor.withValues(alpha: 0.15),
                  ),
                ),

                // 3. Active Outer Progress Indicator Ring (Filling / Spinning)
                SizedBox(
                  width: 180,
                  height: 180,
                  child: progressValue == null
                      ? CircularProgressIndicator(
                          strokeWidth: 4.0,
                          color: statusColor,
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: progressValue),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return CircularProgressIndicator(
                              value: value,
                              strokeWidth: 4.0,
                              color: statusColor,
                              strokeCap: StrokeCap.round,
                            );
                          },
                        ),
                ),

                // 4. Inner Content Circle
                Container(
                  width: 154,
                  height: 154,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cardBackground,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: _buildCircleContent(
                      isSuccess: isSuccess,
                      isFailed: isFailed,
                      isProcessing: isProcessing,
                      statusColor: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // STATUS LABEL & SUBTITLE
        Text(
          _getStatusTitle(),
          style: TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: statusColor,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _getStatusSubtitle(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontSans,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),

        // ACTION BUTTONS
        SizedBox(
          width: double.infinity,
          child: isFailed
              ? Column(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSmall,
                          ),
                        ),
                      ),
                      onPressed: _isCancelling ? null : _retryEnrollment,
                      child: const Text(
                        "RETRY ENROLLMENT",
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontMono,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isCancelling ? null : _cancelAndClose,
                      child: const Text(
                        "CLOSE",
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontMono,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess
                        ? AppColors.successGreen
                        : AppColors.cyanAccent.withValues(alpha: 0.15),
                    foregroundColor:
                        isSuccess ? Colors.black : AppColors.cyanAccent,
                    side: BorderSide(
                      color: isSuccess
                          ? AppColors.successGreen
                          : AppColors.cyanAccent,
                    ),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSmall,
                      ),
                    ),
                  ),
                  onPressed: _isCancelling ? null : _cancelAndClose,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isCancelling) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.cyanAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        isSuccess
                            ? "DONE"
                            : _isCancelling
                                ? "CANCELING..."
                                : "CANCEL",
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fontMono,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCircleContent({
    required bool isSuccess,
    required bool isFailed,
    required bool isProcessing,
    required Color statusColor,
  }) {
    if (isSuccess) {
      return const Icon(
        Icons.check_rounded,
        color: AppColors.successGreen,
        size: 56,
      );
    }

    if (isFailed) {
      return const Icon(
        Icons.priority_high_rounded,
        color: AppColors.errorRed,
        size: 56,
      );
    }

    switch (_currentStatus) {
      case EnrollmentStatus.placeFirstFinger:
      case EnrollmentStatus.placeSecondFinger:
        return Icon(
          Icons.touch_app_rounded,
          color: statusColor,
          size: 52,
        );
      case EnrollmentStatus.raiseFinger:
        return Icon(
          Icons.pan_tool_rounded,
          color: statusColor,
          size: 52,
        );
      default:
        return Icon(
          Icons.fingerprint_rounded,
          color: statusColor,
          size: 52,
        );
    }
  }

  String _getStatusTitle() {
    if (_isCancelling) return "CANCELING...";

    switch (_currentStatus) {
      case EnrollmentStatus.enrolling:
      case EnrollmentStatus.idle:
        return "INITIALIZING SCANNER...";
      case EnrollmentStatus.placeFirstFinger:
        return "FIRST SCAN (1/2)";
      case EnrollmentStatus.raiseFinger:
        return "LIFT FINGER";
      case EnrollmentStatus.placeSecondFinger:
        return "SECOND SCAN (2/2)";
      case EnrollmentStatus.success:
        return "ENROLLMENT SUCCESSFUL";
      case EnrollmentStatus.failed:
        return "ENROLLMENT FAILED";
      case EnrollmentStatus.cancelled:
        return "ENROLLMENT CANCELED";
    }
  }

  String _getStatusSubtitle() {
    if (_isCancelling) return "Reverting terminal state to IDLE";

    switch (_currentStatus) {
      case EnrollmentStatus.enrolling:
      case EnrollmentStatus.idle:
        return "Preparing hardware biometric sensor";
      case EnrollmentStatus.placeFirstFinger:
        return "Place finger firmly onto the scanner surface";
      case EnrollmentStatus.raiseFinger:
        return "Lift your finger off the scanner surface";
      case EnrollmentStatus.placeSecondFinger:
        return "Place the same finger back onto the scanner";
      case EnrollmentStatus.success:
        return "Biometric print registered and saved to locker";
      case EnrollmentStatus.failed:
        return "Biometric scan mismatch or timed out";
      case EnrollmentStatus.cancelled:
        return "Session canceled by user";
    }
  }
}
