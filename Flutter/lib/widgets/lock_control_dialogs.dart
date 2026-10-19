import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/lock_model.dart';
import '../services/auth_service.dart';
import '../services/lock_service.dart';
import 'locksync_text_field.dart';

/// Dialog for renaming the connected locker device.
class DeviceRenameDialog extends StatefulWidget {
  final String currentName;
  final VoidCallback onRenamed;

  const DeviceRenameDialog({
    super.key,
    required this.currentName,
    required this.onRenamed,
  });

  @override
  State<DeviceRenameDialog> createState() => _DeviceRenameDialogState();
}

class _DeviceRenameDialogState extends State<DeviceRenameDialog> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newName = _controller.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSaving = true);
    final success = await LockService.instance.updateDeviceName(newName);
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        widget.onRenamed();
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      title: const Text(
        'RENAME DEVICE',
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
          const Text(
            'Enter a custom identifier for this locker unit.',
            style: TextStyle(
              fontFamily: AppTextStyles.fontSans,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          LockSyncTextField(
            label: 'DEVICE NAME',
            placeholder: 'e.g. LOCKER 01',
            prefixIcon: Icons.edit_outlined,
            controller: _controller,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text(
            AppStrings.cancel,
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cyanAccent,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.background,
                  ),
                )
              : const Text(
                  'SAVE',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Confirmation dialog before purging a fingerprint slot.
class DeleteSlotDialog extends StatefulWidget {
  final int slotID;
  final String label;

  const DeleteSlotDialog({
    super.key,
    required this.slotID,
    required this.label,
  });

  @override
  State<DeleteSlotDialog> createState() => _DeleteSlotDialogState();
}

class _DeleteSlotDialogState extends State<DeleteSlotDialog> {
  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    setState(() => _isDeleting = true);
    await LockService.instance.deleteFingerprintSlot(widget.slotID);
    if (mounted) {
      Navigator.pop(context);
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
        'REMOVE FINGERPRINT',
        style: TextStyle(
          fontFamily: AppTextStyles.fontMono,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textPrimary,
        ),
      ),
      content: Text(
        'Are you sure you want to remove "${widget.label}" (Slot #${widget.slotID}) from the ES608 sensor and Firebase?',
        style: const TextStyle(
          fontFamily: AppTextStyles.fontSans,
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: const Text(
            AppStrings.cancel,
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isDeleting ? null : _handleDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorRed,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
            elevation: 0,
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textPrimary,
                  ),
                )
              : const Text(
                  'REMOVE',
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

/// Dialog displaying comprehensive hardware telemetry from LockDevice.
class DeviceInfoDialog extends StatelessWidget {
  final LockDevice? device;

  const DeviceInfoDialog({super.key, this.device});

  static Widget _buildRow(
    String label,
    String value, {
    bool isHighlight = false,
    Color? overrideColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontSans,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: overrideColor ??
                  (isHighlight ? const Color(0xFF00E676) : AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1.2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.cyanAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall - 2),
            ),
            child: const Icon(
              Icons.developer_board_rounded,
              size: 18,
              color: AppColors.cyanAccent,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'DEVICE INFORMATION',
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow('Device ID', device?.ID ?? 'locker_01'),
            const Divider(color: AppColors.borderSubtle, height: 16),
            _buildRow('Device Name', device?.name ?? 'LOCKER 01'),
            const Divider(color: AppColors.borderSubtle, height: 16),
            _buildRow(
              'Lock State',
              (device?.isLocked ?? true) ? 'LOCKED' : 'UNLOCKED',
            ),
            const Divider(color: AppColors.borderSubtle, height: 16),
            _buildRow(
              'Motion Sensor',
              (device?.motionDetected ?? false) ? 'MOTION DETECTED' : 'STILL',
            ),
            const Divider(color: AppColors.borderSubtle, height: 16),
            _buildRow(
              'Security Alert',
              (device?.unauthorizedAttempt ?? false)
                  ? 'UNAUTHORIZED ATTEMPT'
                  : 'CLEAR',
              overrideColor: (device?.unauthorizedAttempt ?? false)
                  ? AppColors.errorRed
                  : const Color(0xFF00E676),
            ),
            const Divider(color: AppColors.borderSubtle, height: 16),
            _buildRow('Enroll Status', device?.enrollStatus.value ?? 'IDLE'),
            const Divider(color: AppColors.borderSubtle, height: 16),
            _buildRow('Last Payload', device?.lastAction ?? 'INITIALIZED'),
            const Divider(color: AppColors.borderSubtle, height: 16),
            _buildRow('Biometric Hardware', 'ES608 Optical Module'),
            const Divider(color: AppColors.borderSubtle, height: 16),
            _buildRow('Telemetry Stream', 'Firebase RTDB Active', isHighlight: true),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            key: const Key('close_device_info_dialog_button'),
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanAccent,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              elevation: 0,
            ),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog for updating the Master PIN passcode.
class ChangePasswordDialog extends StatefulWidget {
  final Function(String message, {bool isError}) onShowSnackBar;

  const ChangePasswordDialog({
    super.key,
    required this.onShowSnackBar,
  });

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();

    final result = AuthService.instance.updateMasterPin(
      currentPin: currentPin,
      newPin: newPin,
    );

    if (!result.success) {
      setState(() => _errorMessage = result.errorMessage ?? 'Failed to update PIN.');
    } else {
      Navigator.pop(context);
      widget.onShowSnackBar('MASTER PIN UPDATED SUCCESSFULLY');
    }
  }

  @override
  Widget build(BuildContext context) {
    final operatorId = AuthService.instance.currentUserId ?? 'anon_operator';

    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1.2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.cyanAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall - 2),
            ),
            child: const Icon(
              Icons.password_rounded,
              size: 18,
              color: AppColors.cyanAccent,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'CHANGE MASTER PIN',
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operator ID: $operatorId',
              style: const TextStyle(
                fontFamily: AppTextStyles.fontMono,
                fontSize: 10.5,
                color: AppColors.cyanAccent,
              ),
            ),
            const SizedBox(height: 14),
            LockSyncTextField(
              label: 'CURRENT MASTER PIN',
              placeholder: 'Current PIN passcode',
              prefixIcon: Icons.lock_outline_rounded,
              controller: _currentPinController,
              obscureText: _obscureCurrent,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrent
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
            const SizedBox(height: 14),
            LockSyncTextField(
              label: 'NEW MASTER PIN',
              placeholder: '4 to 8 digits',
              prefixIcon: Icons.pin_outlined,
              controller: _newPinController,
              obscureText: _obscureNew,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            const SizedBox(height: 14),
            LockSyncTextField(
              label: 'CONFIRM NEW PIN',
              placeholder: 'Re-enter new PIN',
              prefixIcon: Icons.pin_outlined,
              controller: _confirmPinController,
              obscureText: _obscureConfirm,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
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
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('cancel_change_pin_button'),
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  AppStrings.cancel,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                key: const Key('submit_change_pin_button'),
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyanAccent,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text(
                  'UPDATE PIN',
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}