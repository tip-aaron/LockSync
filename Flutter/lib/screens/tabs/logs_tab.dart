import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';

// -----------------------------------------------------------------------------
// 1. LOG EVENT ENUM & UI HELPER EXTENSIONS
// -----------------------------------------------------------------------------
enum LogEvent {
  remoteLocked,
  remoteUnlocked,
  fingerprintEnrolled,
  fingerprintEnrollmentFailed,
  fingerprintEnrollmentCancelled,
  fingerprintEnrollmentStarted,
  fingerprintFirstScanComplete,
  fingerprintSecondScanComplete,
  fingerprintUnlocked,
  physicalButtonLocked,
  fingerprintDeleted,
  allFingerprintsDeleted,
  alarmDisarmed,
  unauthorizedAttempt,
  unknown;

  static LogEvent fromString(String? raw) {
    final upper = raw?.trim().toUpperCase() ?? '';

    if (upper.startsWith('FP_DELETED_SLOT_') ||
        upper.startsWith('FINGERPRINT_DELETED_SLOT_')) {
      return LogEvent.fingerprintDeleted;
    }

    switch (upper) {
      case 'REMOTE_LOCKED':
        return LogEvent.remoteLocked;
      case 'REMOTE_UNLOCKED':
      case 'REMOTE_UNLOCK':
        return LogEvent.remoteUnlocked;
      case 'FINGERPRINT_ENROLLED':
        return LogEvent.fingerprintEnrolled;
      case 'FINGERPRINT_ENROLLMENT_FAILED':
        return LogEvent.fingerprintEnrollmentFailed;
      case 'FINGERPRINT_ENROLLMENT_CANCELLED':
        return LogEvent.fingerprintEnrollmentCancelled;
      case 'FINGERPRINT_ENROLLMENT_STARTED':
        return LogEvent.fingerprintEnrollmentStarted;
      case 'FINGERPRINT_FIRST_SCAN_COMPLETE':
        return LogEvent.fingerprintFirstScanComplete;
      case 'FINGERPRINT_SECOND_SCAN_COMPLETE':
      case 'FINGERPRINT_SECOND_SCAN_COMPLET': // Catches legacy truncated logs
        return LogEvent.fingerprintSecondScanComplete;
      case 'FINGERPRINT_UNLOCKED':
        return LogEvent.fingerprintUnlocked;
      case 'PHYSICAL_BUTTON_LOCKED':
        return LogEvent.physicalButtonLocked;
      case 'FINGERPRINT_DELETED':
        return LogEvent.fingerprintDeleted;
      case 'ALL_FINGERPRINTS_DELETED':
        return LogEvent.allFingerprintsDeleted;
      case 'ALARM_DISARMED':
        return LogEvent.alarmDisarmed;
      case 'UNAUTHORIZED_ATTEMPT':
        return LogEvent.unauthorizedAttempt;
      default:
        return LogEvent.unknown;
    }
  }

  /// Logical priority order for tie-breaking events with identical timestamps
  int get stepPriority {
    switch (this) {
      case LogEvent.fingerprintEnrollmentStarted:
        return 1;
      case LogEvent.fingerprintFirstScanComplete:
        return 2;
      case LogEvent.fingerprintSecondScanComplete:
        return 3;
      case LogEvent.fingerprintEnrolled:
      case LogEvent.fingerprintEnrollmentFailed:
      case LogEvent.fingerprintEnrollmentCancelled:
        return 4;
      default:
        return 5;
    }
  }

  String get description {
    switch (this) {
      case LogEvent.remoteLocked:
        return 'Locker locked remotely';
      case LogEvent.remoteUnlocked:
        return 'Locker unlocked remotely';
      case LogEvent.fingerprintEnrolled:
        return 'Fingerprint enrolled successfully';
      case LogEvent.fingerprintEnrollmentFailed:
        return 'Fingerprint enrollment failed';
      case LogEvent.fingerprintEnrollmentCancelled:
        return 'Fingerprint enrollment cancelled';
      case LogEvent.fingerprintEnrollmentStarted:
        return 'Enrollment started';
      case LogEvent.fingerprintFirstScanComplete:
        return 'First scan completed';
      case LogEvent.fingerprintSecondScanComplete:
        return 'Second scan completed';
      case LogEvent.fingerprintUnlocked:
        return 'Unlocked with fingerprint';
      case LogEvent.physicalButtonLocked:
        return 'Locked using physical button';
      case LogEvent.fingerprintDeleted:
        return 'Fingerprint deleted';
      case LogEvent.allFingerprintsDeleted:
        return 'All saved fingerprints deleted';
      case LogEvent.alarmDisarmed:
        return 'Security alarm disarmed';
      case LogEvent.unauthorizedAttempt:
        return 'Unauthorized access attempt';
      case LogEvent.unknown:
        return 'Unknown activity';
    }
  }

  IconData get icon {
    switch (this) {
      case LogEvent.remoteLocked:
      case LogEvent.physicalButtonLocked:
        return Icons.lock_outline_rounded;
      case LogEvent.remoteUnlocked:
      case LogEvent.fingerprintUnlocked:
        return Icons.lock_open_rounded;
      case LogEvent.fingerprintEnrolled:
        return Icons.fingerprint_rounded;
      case LogEvent.fingerprintEnrollmentFailed:
        return Icons.error_outline_rounded;
      case LogEvent.fingerprintEnrollmentCancelled:
        return Icons.cancel_outlined;
      case LogEvent.fingerprintEnrollmentStarted:
      case LogEvent.fingerprintFirstScanComplete:
      case LogEvent.fingerprintSecondScanComplete:
        return Icons.touch_app_rounded;
      case LogEvent.fingerprintDeleted:
        return Icons.delete_outline_rounded;
      case LogEvent.allFingerprintsDeleted:
        return Icons.delete_sweep_rounded;
      case LogEvent.alarmDisarmed:
        return Icons.alarm_off_rounded;
      case LogEvent.unauthorizedAttempt:
        return Icons.gpp_bad_rounded;
      case LogEvent.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color get color {
    switch (this) {
      case LogEvent.remoteLocked:
      case LogEvent.physicalButtonLocked:
        return AppColors.cyanAccent;
      case LogEvent.remoteUnlocked:
      case LogEvent.fingerprintUnlocked:
      case LogEvent.fingerprintEnrolled:
      case LogEvent.alarmDisarmed:
        return AppColors.successGreen;
      case LogEvent.fingerprintEnrollmentFailed:
      case LogEvent.allFingerprintsDeleted:
      case LogEvent.fingerprintDeleted:
      case LogEvent.unauthorizedAttempt:
        return AppColors.errorRed;
      case LogEvent.fingerprintEnrollmentCancelled:
        return AppColors.textSecondary;
      case LogEvent.fingerprintEnrollmentStarted:
      case LogEvent.fingerprintFirstScanComplete:
      case LogEvent.fingerprintSecondScanComplete:
        return AppColors.cyanAccent;
      case LogEvent.unknown:
        return AppColors.textMuted;
    }
  }

  bool get isEnrollmentStep {
    return this == LogEvent.fingerprintEnrollmentStarted ||
        this == LogEvent.fingerprintFirstScanComplete ||
        this == LogEvent.fingerprintSecondScanComplete ||
        this == LogEvent.fingerprintEnrolled ||
        this == LogEvent.fingerprintEnrollmentFailed ||
        this == LogEvent.fingerprintEnrollmentCancelled;
  }

  bool get isEnrollmentTerminal {
    return this == LogEvent.fingerprintEnrolled ||
        this == LogEvent.fingerprintEnrollmentFailed ||
        this == LogEvent.fingerprintEnrollmentCancelled;
  }
}

// -----------------------------------------------------------------------------
// 2. DATA MODELS & TIMELINE GROUPING LOGIC
// -----------------------------------------------------------------------------
class LogItem {
  final String id;
  final LogEvent event;
  final DateTime timestamp;
  final String rawEvent;
  final int? slotId;

  LogItem({
    required this.id,
    required this.event,
    required this.timestamp,
    required this.rawEvent,
    this.slotId,
  });

  factory LogItem.fromRTDB(String key, Map<dynamic, dynamic> data) {
    final rawTs = data['timestamp'];
    final tsInt = rawTs is int ? rawTs : int.tryParse(rawTs?.toString() ?? '');

    final DateTime dt = tsInt != null
        ? DateTime.fromMillisecondsSinceEpoch(
            tsInt < 100000000000 ? tsInt * 1000 : tsInt)
        : (DateTime.tryParse(rawTs?.toString() ?? '') ?? DateTime.now());

    final rawEventString = data['event']?.toString() ?? '';
    final upper = rawEventString.toUpperCase();

    int? extractedSlot;
    if (upper.startsWith('FP_DELETED_SLOT_')) {
      extractedSlot = int.tryParse(upper.replaceAll('FP_DELETED_SLOT_', ''));
    } else if (upper.startsWith('FINGERPRINT_DELETED_SLOT_')) {
      extractedSlot = int.tryParse(upper.replaceAll('FINGERPRINT_DELETED_SLOT_', ''));
    }

    return LogItem(
      id: key,
      event: LogEvent.fromString(rawEventString),
      timestamp: dt,
      rawEvent: rawEventString,
      slotId: extractedSlot,
    );
  }

  String get formattedDescription {
    if (event == LogEvent.fingerprintDeleted && slotId != null) {
      return 'Fingerprint (Slot #$slotId) deleted';
    }
    if (event == LogEvent.unknown) {
      return rawEvent.isNotEmpty ? 'Unknown Activity ("$rawEvent")' : 'Unknown Activity';
    }
    return event.description;
  }
}

abstract class TimelineNode {
  final DateTime timestamp;
  final String keyId;
  TimelineNode(this.timestamp, this.keyId);
}

class SingleLogNode extends TimelineNode {
  final LogItem log;
  SingleLogNode(this.log) : super(log.timestamp, log.id);
}

class GroupTimelineNode extends TimelineNode {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final List<LogItem> logs;
  final bool isTerminalGroup;

  GroupTimelineNode({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.logs,
    this.isTerminalGroup = true,
  }) : super(logs.last.timestamp, logs.last.id);
}

List<TimelineNode> processLogsIntoTimelineNodes(
    List<LogItem> chronologicalLogs, DateFormat dateFormat) {
  final List<TimelineNode> nodes = [];
  List<LogItem>? enrollmentSession;
  List<LogItem>? attemptSession;

  void flushEnrollment() {
    if (enrollmentSession == null || enrollmentSession!.isEmpty) return;

    final finalEvent = enrollmentSession!.last.event;
    final title = finalEvent == LogEvent.fingerprintEnrolled
        ? "Fingerprint Enrollment Succeeded"
        : finalEvent == LogEvent.fingerprintEnrollmentFailed
            ? "Fingerprint Enrollment Failed"
            : finalEvent == LogEvent.fingerprintEnrollmentCancelled
                ? "Fingerprint Enrollment Cancelled"
                : "Fingerprint Enrollment Process";

    nodes.add(GroupTimelineNode(
      title: title,
      subtitle:
          "${enrollmentSession!.length} Steps • ${dateFormat.format(enrollmentSession!.last.timestamp)}",
      color: finalEvent.color,
      icon: Icons.fingerprint_rounded,
      logs: List.from(enrollmentSession!),
      isTerminalGroup: finalEvent.isEnrollmentTerminal,
    ));
    enrollmentSession = null;
  }

  void flushAttempt() {
    if (attemptSession == null || attemptSession!.isEmpty) return;
    final count = attemptSession!.length;
    final title = count == 1
        ? "Unauthorized Attempt Detected"
        : "$count Unauthorized Attempts Detected";

    nodes.add(GroupTimelineNode(
      title: title,
      subtitle:
          "$count ${count == 1 ? 'Event' : 'Events'} • ${dateFormat.format(attemptSession!.last.timestamp)}",
      color: AppColors.errorRed,
      icon: Icons.gpp_bad_rounded,
      logs: List.from(attemptSession!),
      isTerminalGroup: true,
    ));
    attemptSession = null;
  }

  for (final log in chronologicalLogs) {
    if (log.event.isEnrollmentStep) {
      flushAttempt();

      if (log.event == LogEvent.fingerprintEnrollmentStarted && enrollmentSession != null) {
        flushEnrollment();
      }

      enrollmentSession ??= [];
      enrollmentSession!.add(log);

      if (log.event.isEnrollmentTerminal) {
        flushEnrollment();
      }
      continue;
    } else {
      flushEnrollment();
    }

    if (log.event == LogEvent.unauthorizedAttempt) {
      attemptSession ??= [];
      attemptSession!.add(log);
      continue;
    } else {
      flushAttempt();
    }

    nodes.add(SingleLogNode(log));
  }

  flushEnrollment();
  flushAttempt();

  return nodes.reversed.toList();
}

// -----------------------------------------------------------------------------
// 3. LOGS TAB MAIN WIDGET
// -----------------------------------------------------------------------------
class LogsTab extends StatefulWidget {
  const LogsTab({super.key});

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy • hh:mm:ss a');

  Future<void> _confirmDeleteAllLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text(
          "PURGE AUDIT LOGS",
          style: TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.errorRed,
            letterSpacing: 1.1,
          ),
        ),
        content: const Text(
          "Are you sure you want to permanently delete all audit logs? This action cannot be undone.",
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

    try {
      await FirebaseDatabase.instance.ref('lockers/locker_01/logs').remove();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to delete logs: $e"),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16.0,
        title: const Text("AUDIT LOGS", style: AppTextStyles.heading),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.errorRed,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _confirmDeleteAllLogs,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text(
                "CLEAR ALL",
                style: TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance
            .ref('lockers/locker_01/logs')
            .orderByChild('timestamp')
            .onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading logs: ${snapshot.error}",
                style: const TextStyle(
                  color: AppColors.errorRed,
                  fontFamily: AppTextStyles.fontSans,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.cyanAccent),
            );
          }

          final dbEvent = snapshot.data;
          if (dbEvent == null || dbEvent.snapshot.value == null) {
            return const Center(
              child: Text(
                "No audit logs found.",
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: AppTextStyles.fontMono,
                ),
              ),
            );
          }

          final Map<dynamic, dynamic> logsMap =
              Map<dynamic, dynamic>.from(dbEvent.snapshot.value as Map);

          final List<LogItem> rawLogs = logsMap.entries.map((entry) {
            final val = Map<dynamic, dynamic>.from(entry.value as Map);
            return LogItem.fromRTDB(entry.key.toString(), val);
          }).toList();

          // Multi-tier sort tie-breaker to handle identical timestamps
          rawLogs.sort((a, b) {
            final timeComp = a.timestamp.compareTo(b.timestamp);
            if (timeComp != 0) return timeComp;

            final priorityComp = a.event.stepPriority.compareTo(b.event.stepPriority);
            if (priorityComp != 0) return priorityComp;

            return a.id.compareTo(b.id);
          });

          final timelineNodes = processLogsIntoTimelineNodes(rawLogs, _dateFormat);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            itemCount: timelineNodes.length,
            itemBuilder: (context, index) {
              final node = timelineNodes[index];
              final isFirst = index == 0;
              final isLast = index == timelineNodes.length - 1;

              return TweenAnimationBuilder<double>(
                key: ValueKey(node.keyId),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: AppDimensions.animDurationStandard,
                curve: Curves.easeOutCubic,
                builder: (context, opacity, child) {
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, (1 - opacity) * 16),
                      child: child,
                    ),
                  );
                },
                child: node is SingleLogNode
                    ? _buildSingleTimelineItem(node, isFirst, isLast)
                    : _buildGroupItem(node as GroupTimelineNode, isFirst, isLast),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SINGLE LOG TIMELINE ITEM
  // ---------------------------------------------------------------------------
  Widget _buildSingleTimelineItem(SingleLogNode node, bool isFirst, bool isLast) {
    final color = node.log.event.color;

    return Stack(
      children: [
        _buildTimelineLine(isFirst: isFirst, isLast: isLast, bulletTopOffset: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBullet(color: color, icon: node.log.event.icon, topOffset: 10),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.log.formattedDescription,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fontSans,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateFormat.format(node.log.timestamp),
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fontMono,
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
  // UNIFIED COLLAPSIBLE GROUP TIMELINE ITEM
  // ---------------------------------------------------------------------------
  Widget _buildGroupItem(GroupTimelineNode node, bool isFirst, bool isLast) {
    return Stack(
      children: [
        _buildTimelineLine(isFirst: isFirst, isLast: isLast, bulletTopOffset: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBullet(color: node.color, icon: node.icon, topOffset: 10),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    border: Border.all(
                      color: node.color.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      splashColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      shape: const RoundedRectangleBorder(side: BorderSide.none),
                      collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      iconColor: node.color,
                      collapsedIconColor: AppColors.textSecondary,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: node.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(node.icon, color: node.color, size: 16),
                      ),
                      title: Text(
                        node.title,
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontSans,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: node.color,
                        ),
                      ),
                      subtitle: Text(
                        node.subtitle,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fontMono,
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      children: [
                        const Divider(color: AppColors.borderDivider, height: 1),
                        const SizedBox(height: 16),
                        Column(
                          children: List.generate(node.logs.length, (idx) {
                            final subLog = node.logs[idx];
                            final isLastStep = idx == node.logs.length - 1;
                            final stepColor = (isLastStep && node.isTerminalGroup)
                                ? node.color
                                : AppColors.textMuted;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: stepColor,
                                      ),
                                    ),
                                    if (!isLastStep)
                                      Container(
                                        width: 2,
                                        height: 24,
                                        color: AppColors.borderSubtle,
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subLog.formattedDescription,
                                        style: TextStyle(
                                          fontFamily: AppTextStyles.fontSans,
                                          fontSize: 12.5,
                                          fontWeight: isLastStep
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isLastStep
                                              ? AppColors.textPrimary
                                              : AppColors.textSubtle,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _dateFormat.format(subLog.timestamp),
                                        style: const TextStyle(
                                          fontFamily: AppTextStyles.fontMono,
                                          fontSize: 10,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      if (!isLastStep) const SizedBox(height: 12),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ],
                    ),
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
  // TIMELINE BULLET AND LINE CONNECTORS
  // ---------------------------------------------------------------------------
  Widget _buildTimelineLine({
    required bool isFirst,
    required bool isLast,
    required double bulletTopOffset,
  }) {
    return Positioned(
      left: 15,
      top: isFirst ? bulletTopOffset + 16 : 0,
      bottom: isLast ? 16 : 0,
      child: Container(
        width: 2,
        color: AppColors.borderSubtle,
      ),
    );
  }

  Widget _buildBullet({
    required Color color,
    required IconData icon,
    required double topOffset,
  }) {
    return Container(
      width: 32,
      height: 32,
      margin: EdgeInsets.only(top: topOffset),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.cardBackground,
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}
