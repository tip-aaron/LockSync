import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../models/lock_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/fingerprint_enrollment_modal.dart';
import '../../widgets/lock_control_dialogs.dart';
import '../auth_screen.dart';

class SettingsTab extends StatelessWidget {
  final LockDevice? device;
  final void Function(String message, {bool isError}) onShowSnackBar;

  const SettingsTab({
    super.key,
    required this.device,
    required this.onShowSnackBar,
  });

  void _showDeviceInformationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => DeviceInfoDialog(device: device),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ChangePasswordDialog(onShowSnackBar: onShowSnackBar),
    );
  }

  void _confirmDeleteSlot(BuildContext context, int slotID, String label) {
    showDialog(
      context: context,
      builder: (_) => DeleteSlotDialog(slotID: slotID, label: label),
    );
  }

  void _handleLockApp(BuildContext context) {
    AuthService.instance.lockApp();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registeredSlots = device?.registeredSlots.values.toList() ?? [];

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'DEVICE SETTINGS',
            subtitle: 'Hardware telemetry and access security configurations.',
          ),
          const SizedBox(height: 18),

          _SettingsMenuButton(
            key: const Key('device_information_button'),
            icon: Icons.info_outline_rounded,
            title: 'DEVICE INFORMATION',
            subtitle: 'Microcontroller, firmware & connection node',
            onTap: () => _showDeviceInformationDialog(context),
          ),
          const SizedBox(height: 12),
          _SettingsMenuButton(
            key: const Key('change_password_button'),
            icon: Icons.password_rounded,
            title: 'CHANGE MASTER PIN',
            subtitle: 'Update local security passcode for app access',
            onTap: () => _showChangePasswordDialog(context),
          ),

          const SizedBox(height: 24),

          const _SectionHeader(
            title: 'BIOMETRIC CREDENTIALS',
            subtitle:
                'Manage authorized fingerprint templates stored on ES608 sensor.',
          ),
          const SizedBox(height: 14),

          _buildFingerprintCard(context, registeredSlots),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => _handleLockApp(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.errorRed,
                side: const BorderSide(color: AppColors.errorRed, width: 1.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
              ),
              child: const Text(
                'LOCK APP SESSION',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFingerprintCard(BuildContext context, List registeredSlots) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REGISTERED FINGERPRINTS',
                style: TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${registeredSlots.length} / ${SensorLimits.maxFingerprintSlots} SLOTS',
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cyanAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (registeredSlots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No fingerprints registered yet.\nTap below to enroll your first biometric credential.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontSans,
                    fontSize: 12.5,
                    color: AppColors.textSubtle,
                    height: 1.4,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: registeredSlots.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.borderSubtle, height: 16),
              itemBuilder: (context, index) {
                final slot = registeredSlots[index];
                return _FingerprintSlotRow(
                  slotID: slot.slotID,
                  label: slot.label,
                  registeredAt: slot.registeredAt.toString(),
                  onDelete: () =>
                      _confirmDeleteSlot(context, slot.slotID, slot.label),
                );
              },
            ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: AppDimensions.dialogInputFieldHeight,
            child: ElevatedButton(
              key: const Key('enroll_fingerprint_button'),
              onPressed: () => showFingerprintEnrollmentModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'ENROLL NEW FINGERPRINT',
                    style: TextStyle(
                      fontFamily: AppTextStyles.fontMono,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: AppTextStyles.subtitle),
      ],
    );
  }
}

class _FingerprintSlotRow extends StatelessWidget {
  final int slotID;
  final String label;
  final String registeredAt;
  final VoidCallback onDelete;

  const _FingerprintSlotRow({
    required this.slotID,
    required this.label,
    required this.registeredAt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.cyanAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          child: const Icon(
            Icons.fingerprint_rounded,
            size: 20,
            color: AppColors.cyanAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fontSans,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SLOT #$slotID',
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fontMono,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cyanAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                registeredAt,
                style: const TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 10,
                  color: AppColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          color: AppColors.errorRed.withValues(alpha: 0.8),
          tooltip: 'Delete Slot',
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _SettingsMenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsMenuButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        splashColor: AppColors.cyanAccent.withValues(alpha: 0.12),
        highlightColor: AppColors.cyanAccent.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                  border: Border.all(color: AppColors.borderInput),
                ),
                child: Icon(icon, size: 20, color: AppColors.cyanAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fontMono,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.fontSans,
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
