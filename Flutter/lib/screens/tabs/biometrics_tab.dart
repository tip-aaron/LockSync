import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:locksyncie/models/command_action.dart';
import 'package:locksyncie/widgets/add_biometric_modal.dart';
import '../../constants/app_constants.dart';
import '../../services/system_status_service.dart';

// -----------------------------------------------------------------------------
// 1. DATA MODEL
// -----------------------------------------------------------------------------
class FingerprintItem {
  final String id;
  final int slotId;
  final String name;
  final DateTime timestamp;
  final DateTime? lastUsed;

  FingerprintItem({
    required this.id,
    required this.slotId,
    required this.name,
    required this.timestamp,
    this.lastUsed,
  });

  factory FingerprintItem.fromRTDB(String key, Map<dynamic, dynamic> data) {
    final parsedSlotId = int.tryParse(key) ?? 0;
    final rawName = data['name']?.toString() ?? 'Fingerprint #$key';

    DateTime parseTimestamp(dynamic raw) {
      final tsInt = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      if (tsInt != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          tsInt < 100000000000 ? tsInt * 1000 : tsInt,
        );
      }
      return DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();
    }

    final ts = parseTimestamp(data['timestamp']);
    final rawLastUsed = data['lastUsed'];
    final lastUsedDt = rawLastUsed != null ? parseTimestamp(rawLastUsed) : null;

    return FingerprintItem(
      id: key,
      slotId: parsedSlotId,
      name: rawName,
      timestamp: ts,
      lastUsed: lastUsedDt,
    );
  }
}

// -----------------------------------------------------------------------------
// 2. BIOMETRICS TAB MAIN WIDGET
// -----------------------------------------------------------------------------
class BiometricsTab extends StatefulWidget {
  const BiometricsTab({super.key});

  @override
  State<BiometricsTab> createState() => _BiometricsTabState();
}

class _BiometricsTabState extends State<BiometricsTab> {
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
  final SystemStatusService _systemStatusService = SystemStatusService.instance;

  int? _deletingSlotId;
  bool _isDeletingAll = false;

  bool get _isProcessing => _deletingSlotId != null || _isDeletingAll;

  Future<void> _showAddBiometricModal() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const AddBiometricModal(),
    );
  }

  /// Waits until the ESP32 acknowledges hardware deletion by resetting
  /// `lockers/locker_01/command/action` back to `CommandAction.idle` (0).
  Future<void> _waitForCommandAck({Duration timeout = const Duration(seconds: 10)}) async {
    final completer = Completer<void>();
    final ref = FirebaseDatabase.instance.ref('lockers/locker_01/command/action');
    StreamSubscription<DatabaseEvent>? sub;
    Timer? timer;

    sub = ref.onValue.listen((event) {
      final val = event.snapshot.value;
      final intAction = val is int ? val : int.tryParse(val?.toString() ?? '') ?? 0;

      if (intAction == CommandAction.idle.value) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future;
    timer.cancel();
    await sub.cancel();
  }

  Future<void> _confirmDeleteFingerprint(FingerprintItem fp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text(
          "REMOVE BIOMETRIC",
          style: TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.errorRed,
            letterSpacing: 1.1,
          ),
        ),
        content: Text(
          "Are you sure you want to delete \"${fp.name}\" (Slot #${fp.slotId})?",
          style: const TextStyle(
            fontFamily: AppTextStyles.fontSans,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              "CANCEL",
              style: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              "DELETE",
              style: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _deletingSlotId = fp.slotId;
    });

    try {
      // 1. Dispatch deletion command to ESP32
      await FirebaseDatabase.instance.ref('lockers/locker_01/command').update({
        'param': fp.slotId,
        'action': CommandAction.deleteFingerprint.value,
      });

      // 2. Wait until ESP32 completes hardware delete & resets command action to IDLE
      await _waitForCommandAck();

      // 3. Remove metadata node from RTDB
      await FirebaseDatabase.instance
          .ref('lockers/locker_01/fingerprints/${fp.id}')
          .remove();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to remove biometric: $e"),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingSlotId = null;
        });
      }
    }
  }

  Future<void> _confirmDeleteAllFingerprints() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text(
          "PURGE ALL BIOMETRICS",
          style: TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.errorRed,
            letterSpacing: 1.1,
          ),
        ),
        content: const Text(
          "Are you sure you want to permanently delete all registered fingerprints? This action cannot be undone.",
          style: TextStyle(
            fontFamily: AppTextStyles.fontSans,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              "CANCEL",
              style: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              "DELETE ALL",
              style: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeletingAll = true;
    });

    try {
      // 1. Dispatch bulk purge command (-1) to ESP32
      await FirebaseDatabase.instance.ref('lockers/locker_01/command').update({
        'param': -1,
        'action': CommandAction.deleteFingerprint.value,
      });

      // 2. Wait until ESP32 acknowledges hardware purge
      await _waitForCommandAck();

      // 3. Clear metadata node in RTDB
      await FirebaseDatabase.instance
          .ref('lockers/locker_01/fingerprints')
          .remove();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete biometrics: $e"),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAll = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _systemStatusService.isReachableNotifier,
      builder: (context, isReachable, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('lockers/locker_01/fingerprints')
                .onValue,
            builder: (context, snapshot) {
              int count = 0;
              List<FingerprintItem> fingerprints = [];

              if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                final rawData = snapshot.data!.snapshot.value;

                if (rawData is Map) {
                  final Map<dynamic, dynamic> map =
                      Map<dynamic, dynamic>.from(rawData);

                  fingerprints = map.entries
                      .where((entry) => entry.value != null && entry.value is Map)
                      .map((entry) {
                    final val = Map<dynamic, dynamic>.from(entry.value as Map);
                    return FingerprintItem.fromRTDB(entry.key.toString(), val);
                  }).toList();
                } else if (rawData is List) {
                  for (int i = 0; i < rawData.length; i++) {
                    final item = rawData[i];
                    if (item != null && item is Map) {
                      final val = Map<dynamic, dynamic>.from(item);
                      fingerprints.add(
                        FingerprintItem.fromRTDB(i.toString(), val),
                      );
                    }
                  }
                }

                fingerprints.sort((a, b) => a.slotId.compareTo(b.slotId));
                count = fingerprints.length;
              }

              final bool hasFingerprints = fingerprints.isNotEmpty;
              final bool canAddBiometric = isReachable && !_isProcessing;

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // HEADER TITLE BAR
                  SliverAppBar(
                    backgroundColor: AppColors.background,
                    elevation: 0,
                    pinned: true,
                    centerTitle: false,
                    titleSpacing: 16.0,
                    title: Row(
                      children: [
                        const Text("BIOMETRICS", style: AppTextStyles.heading),
                        const SizedBox(width: 8),
                        Text(
                          "[$count/162 registered]",
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontMono,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // TOOLBAR BELOW HEADER
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              disabledForegroundColor: AppColors.textMuted,
                              foregroundColor: AppColors.errorRed,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              backgroundColor: (hasFingerprints && !_isProcessing)
                                  ? AppColors.errorRed.withValues(alpha: 0.1)
                                  : AppColors.borderSubtle.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusSmall,
                                ),
                                side: BorderSide(
                                  color: (hasFingerprints && !_isProcessing)
                                      ? AppColors.errorRed.withValues(alpha: 0.3)
                                      : AppColors.borderSubtle.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            onPressed: (hasFingerprints && !_isProcessing)
                                ? _confirmDeleteAllFingerprints
                                : null,
                            icon: _isDeletingAll
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.errorRed,
                                    ),
                                  )
                                : Icon(
                                    Icons.delete_sweep_rounded,
                                    size: 16,
                                    color: (hasFingerprints && !_isProcessing)
                                        ? AppColors.errorRed
                                        : AppColors.textMuted,
                                  ),
                            label: Text(
                              _isDeletingAll ? "Deleting..." : "Delete all",
                              style: TextStyle(
                                fontFamily: AppTextStyles.fontMono,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: (hasFingerprints && !_isProcessing)
                                    ? AppColors.errorRed
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              disabledForegroundColor: AppColors.textMuted,
                              foregroundColor: AppColors.cyanAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              backgroundColor: canAddBiometric
                                  ? AppColors.cyanAccent.withValues(alpha: 0.1)
                                  : AppColors.borderSubtle.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusSmall,
                                ),
                                side: BorderSide(
                                  color: canAddBiometric
                                      ? AppColors.cyanAccent.withValues(alpha: 0.3)
                                      : AppColors.borderSubtle.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            onPressed: canAddBiometric ? _showAddBiometricModal : null,
                            icon: Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: canAddBiometric
                                  ? AppColors.cyanAccent
                                  : AppColors.textMuted,
                            ),
                            label: Text(
                              "Add Biometric",
                              style: TextStyle(
                                fontFamily: AppTextStyles.fontMono,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: canAddBiometric
                                    ? AppColors.cyanAccent
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (snapshot.hasError)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          "Error loading biometrics: ${snapshot.error}",
                          style: const TextStyle(
                            color: AppColors.errorRed,
                            fontFamily: AppTextStyles.fontSans,
                          ),
                        ),
                      ),
                    )
                  else if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.cyanAccent),
                      ),
                    )
                  else if (fingerprints.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          "No biometric prints registered.",
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontFamily: AppTextStyles.fontMono,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4.0,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final fp = fingerprints[index];
                            return _buildFingerprintCard(fp);
                          },
                          childCount: fingerprints.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FINGERPRINT CARD ITEM
  // ---------------------------------------------------------------------------
  Widget _buildFingerprintCard(FingerprintItem fp) {
    final lastUsedText = fp.lastUsed != null
        ? _dateFormat.format(fp.lastUsed!)
        : "Never used";

    final bool isDeletingThis = _deletingSlotId == fp.slotId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fp.name,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fontSans,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Last used: $lastUsedText",
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fontMono,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDeletingThis)
                const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.errorRed,
                    ),
                  ),
                )
              else
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.errorRed,
                    size: 20,
                  ),
                  tooltip: "Delete Fingerprint",
                  onPressed: _isProcessing ? null : () => _confirmDeleteFingerprint(fp),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                "Slot No. ${fp.slotId}",
                style: const TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cyanAccent,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "Enrolled: ${_dateFormat.format(fp.timestamp)}",
                style: const TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
