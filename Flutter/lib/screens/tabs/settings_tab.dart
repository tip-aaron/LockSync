import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../auth_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final AuthService _authService = AuthService.instance;

  Future<void> _showChangePinModal() async {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.radiusLarge),
                  ),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.borderSubtle,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        "CHANGE MASTER PIN",
                        style: TextStyle(
                          fontFamily: AppTextStyles.fontMono,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cyanAccent,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Current PIN Input
                      TextFormField(
                        controller: currentPinController,
                        obscureText: obscureCurrent,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: AppTextStyles.fontMono,
                        ),
                        decoration: InputDecoration(
                          labelText: "Current PIN",
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrent
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setModalState(
                              () => obscureCurrent = !obscureCurrent,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.borderSubtle),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.cyanAccent),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.errorRed),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.errorRed),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? "Please enter your current PIN"
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // New PIN Input
                      TextFormField(
                        controller: newPinController,
                        obscureText: obscureNew,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: AppTextStyles.fontMono,
                        ),
                        decoration: InputDecoration(
                          labelText: "New PIN (4-8 digits)",
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setModalState(
                              () => obscureNew = !obscureNew,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.borderSubtle),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.cyanAccent),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.errorRed),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.errorRed),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                        ),
                        validator: (val) {
                          final clean = val?.trim() ?? '';
                          if (clean.length < 4 || clean.length > 8) {
                            return "PIN must be between 4 and 8 digits";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Confirm New PIN Input
                      TextFormField(
                        controller: confirmPinController,
                        obscureText: obscureConfirm,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: AppTextStyles.fontMono,
                        ),
                        decoration: InputDecoration(
                          labelText: "Confirm New PIN",
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setModalState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.borderSubtle),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.cyanAccent),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.errorRed),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppColors.errorRed),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusSmall,
                            ),
                          ),
                        ),
                        validator: (val) {
                          if (val?.trim() != newPinController.text.trim()) {
                            return "New PINs do not match";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(bottomSheetContext).pop(),
                            child: const Text(
                              "CANCEL",
                              style: TextStyle(
                                fontFamily: AppTextStyles.fontMono,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cyanAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusSmall,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;

                              final result = await _authService.updateMasterPin(
                                currentPin: currentPinController.text,
                                newPin: newPinController.text,
                              );

                              if (result.success) {
                                if (!mounted) return;
                                Navigator.of(bottomSheetContext).pop();
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Master PIN updated successfully!"),
                                    backgroundColor: AppColors.successGreen,
                                  ),
                                );
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result.errorMessage ?? "Failed to update PIN.",
                                    ),
                                    backgroundColor: AppColors.errorRed,
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              "UPDATE PIN",
                              style: TextStyle(
                                fontFamily: AppTextStyles.fontMono,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text(
          "LOCK APP & LOGOUT",
          style: TextStyle(
            fontFamily: AppTextStyles.fontMono,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.errorRed,
            letterSpacing: 1.1,
          ),
        ),
        content: const Text(
          "Are you sure you want to lock the system and return to the PIN authentication screen?",
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
              "LOGOUT",
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

    _authService.lockApp();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthScreen()),
      (route) => false,
    );
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
        title: const Text("SYSTEM SETTINGS", style: AppTextStyles.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // SECURITY SECTION HEADER
          const Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              "SECURITY & AUTHENTICATION",
              style: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // CHANGE PIN CARD
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.password_rounded,
                  color: AppColors.cyanAccent,
                  size: 20,
                ),
              ),
              title: const Text(
                "Change Master PIN",
                style: TextStyle(
                  fontFamily: AppTextStyles.fontSans,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: const Text(
                "Update the master passcode used to access the app",
                style: TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
              onTap: _showChangePinModal,
            ),
          ),

          const SizedBox(height: 24),

          // SESSION SECTION HEADER
          const Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              "SESSION MANAGEMENT",
              style: TextStyle(
                fontFamily: AppTextStyles.fontMono,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // LOGOUT CARD
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(
                color: AppColors.errorRed.withValues(alpha: 0.3),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: AppColors.errorRed,
                  size: 20,
                ),
              ),
              title: const Text(
                "Lock & Logout",
                style: TextStyle(
                  fontFamily: AppTextStyles.fontSans,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.errorRed,
                ),
              ),
              subtitle: const Text(
                "Lock the application session and return to entry screen",
                style: TextStyle(
                  fontFamily: AppTextStyles.fontMono,
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: const Icon(
                Icons.logout_rounded,
                color: AppColors.errorRed,
                size: 20,
              ),
              onTap: _confirmLogout,
            ),
          ),
        ],
      ),
    );
  }
}