import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';

class ChangePinDialog extends StatefulWidget {
  final Function(String message, {bool isError}) onShowSnackBar;

  const ChangePinDialog({
    super.key,
    required this.onShowSnackBar,
  });

  @override
  State<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<ChangePinDialog> {
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _isUpdatingPin = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleSavePin() async {
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (newPin != confirmPin) {
      widget.onShowSnackBar(AppStrings.pinMismatchError, isError: true);
      return;
    }

    setState(() => _isUpdatingPin = true);

    final res = AuthService.instance.updateMasterPin(
      currentPin: currentPin,
      newPin: newPin,
    );

    setState(() => _isUpdatingPin = false);

    if (res.success) {
      if (mounted) Navigator.pop(context);
      widget.onShowSnackBar(AppStrings.pinSuccess);
    } else {
      widget.onShowSnackBar(
        res.errorMessage ?? 'Failed to update PIN',
        isError: true,
      );
    }
  }

  Widget _buildPinField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: AppDimensions.dialogInputFieldHeight,
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: AppColors.borderInput, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 14,
              color: AppColors.textPrimary,
              letterSpacing: 2.0,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: '••••••',
              hintStyle: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                fontSize: 13.5,
                color: AppColors.textMuted,
              ),
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
        side: const BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      title: const Text(
        AppStrings.updatePinTitle,
        style: TextStyle(
          fontFamily: AppTextStyles.fontMono,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.updatePinSubtitle,
              style: TextStyle(
                fontFamily: AppTextStyles.fontSans,
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            _buildPinField(
              label: AppStrings.currentPinLabel,
              controller: _currentPinController,
            ),
            const SizedBox(height: 12),
            _buildPinField(
              label: AppStrings.newPinLabel,
              controller: _newPinController,
            ),
            const SizedBox(height: 12),
            _buildPinField(
              label: AppStrings.confirmPinLabel,
              controller: _confirmPinController,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdatingPin ? null : () => Navigator.pop(context),
          child: const Text(
            AppStrings.cancel,
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isUpdatingPin ? null : _handleSavePin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cyanAccent,
            foregroundColor: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
            elevation: 0,
          ),
          child: _isUpdatingPin
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.background,
                  ),
                )
              : const Text(
                  AppStrings.savePin,
                  style: TextStyle(
                    fontFamily: AppTextStyles.fontMono,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
        ),
      ],
    );
  }
}