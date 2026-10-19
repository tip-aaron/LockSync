import 'package:flutter/material.dart' hide Actions;
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../models/lock_model.dart';
import '../../services/lock_service.dart';

class HistoryTab extends StatelessWidget {
  final List<ActionsHistory> history;
  final void Function(String message, {bool isError}) onShowSnackBar;

  const HistoryTab({
    super.key,
    required this.history,
    required this.onShowSnackBar,
  });

  Future<void> _confirmClear(BuildContext context) async {
    final cleared = await showDialog<bool>(
      context: context,
      builder: (_) => _ClearHistoryDialog(count: history.length),
    );
    if (cleared == true) onShowSnackBar('HISTORY CLEARED');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 8.0, 8.0, 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HISTORY LOG',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: AppColors.textPrimary,
                ),
              ),
              if (history.isNotEmpty)
                IconButton(
                  key: const Key('clear_history_button'),
                  onPressed: () => _confirmClear(context),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 22),
                  color: AppColors.errorRed.withValues(alpha: 0.85),
                  tooltip: 'Clear history',
                ),
            ],
          ),
        ),
        const Divider(color: AppColors.borderSubtle, height: 1),
        Expanded(
          child: history.isEmpty
              ? const Center(
                  child: Text(
                    'No access history recorded yet.',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontSans,
                      fontSize: 13,
                      color: AppColors.textSubtle,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final event = history[index];
                    return switch (event) {
                      EnrollmentSessionHistory() => _EnrollmentSessionTile(
                        session: event,
                      ),
                      _ => _HistoryEntryTile(event: event),
                    };
                  },
                ),
        ),
      ],
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  final ActionsHistory event;

  const _HistoryEntryTile({required this.event});

  IconData get _icon => switch (event.action) {
    Actions.ENROLLMENT => Icons.fingerprint_rounded,
    Actions.SLOT_DELETED => Icons.delete_outline_rounded,
    Actions.UNLOCK || Actions.REMOTE_UNLOCK => Icons.lock_open_rounded,
    Actions.MOTION_DETECTED => Icons.sensors_rounded,
    Actions.UNAUTHORIZED_ATTEMPT => Icons.warning_amber_rounded,
    _ => Icons.lock_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.cyanAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
            child: Icon(_icon, color: AppColors.cyanAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.action.value,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fontSans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.description,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fontSans,
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            event.formattedTime,
            style: const TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 10,
              color: AppColors.textSubtle,
            ),
          ),
        ],
      ),
    );
  }
}

/// One enrollment attempt: collapsed shows "ENROLLMENT" + date,
/// expanded lists every status event of that attempt.
class _EnrollmentSessionTile extends StatelessWidget {
  final EnrollmentSessionHistory session;

  const _EnrollmentSessionTile({required this.session});

  Color get _accent => switch (session.enrollStatus) {
    EnrollStatus.COMPLETED => const Color(0xFF00E676),
    EnrollStatus.CANCELED => const Color(0xFFFFB300),
    EnrollStatus.ERROR_PRINTS_DONT_MATCH ||
    EnrollStatus.ERROR_STORAGE_FAILED ||
    EnrollStatus.ERROR_SCAN_FAILED ||
    EnrollStatus.TIMEOUT => AppColors.errorRed,
    _ => AppColors.cyanAccent,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('enroll_${session.id}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(60, 0, 16, 12),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textSubtle,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
            child: Icon(Icons.fingerprint_rounded, color: _accent, size: 20),
          ),
          title: const Text(
            'ENROLLMENT',
            style: TextStyle(
              fontFamily: AppTextStyles.fontSans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            session.formattedTime,
            style: const TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 10,
              color: AppColors.textSubtle,
            ),
          ),
          children: [
            for (final e in session.events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: e.status == session.enrollStatus
                            ? _accent
                            : AppColors.borderInput,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.status.value,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fontMono,
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm:ss a').format(e.timestamp),
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fontMono,
                        fontSize: 10,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClearHistoryDialog extends StatefulWidget {
  final int count;

  const _ClearHistoryDialog({required this.count});

  @override
  State<_ClearHistoryDialog> createState() => _ClearHistoryDialogState();
}

class _ClearHistoryDialogState extends State<_ClearHistoryDialog> {
  bool _isClearing = false;
  String? _errorMessage;

  Future<void> _handleClear() async {
    setState(() {
      _isClearing = true;
      _errorMessage = null;
    });

    final success = await LockService.instance.clearHistory();

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isClearing = false;
        _errorMessage = 'Failed to clear history. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      title: const Text(
        'CLEAR HISTORY',
        style: TextStyle(
          fontFamily: AppTextStyles.fontMono,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Permanently delete all ${widget.count} history entries from Firebase? This cannot be undone.',
            style: const TextStyle(
              fontFamily: AppTextStyles.fontSans,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontSans,
                fontSize: 11.5,
                color: AppColors.errorRed,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isClearing ? null : () => Navigator.pop(context, false),
          child: const Text(
            AppStrings.cancel,
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          key: const Key('confirm_clear_history_button'),
          onPressed: _isClearing ? null : _handleClear,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorRed,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
            elevation: 0,
          ),
          child: _isClearing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textPrimary,
                  ),
                )
              : const Text(
                  'CLEAR ALL',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}
