import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/lock_model.dart';
import '../services/auth_service.dart';
import '../services/lock_service.dart';
import 'fingerprint_enrollment_modal.dart';

class LockControlScreen extends StatefulWidget {
  const LockControlScreen({super.key});

  @override
  State<LockControlScreen> createState() => _LockControlScreenState();
}

class _LockControlScreenState extends State<LockControlScreen>
    with SingleTickerProviderStateMixin {
  // Lock state & telemetry from Firebase
  bool _isLocked = true;
  bool _isProcessing = false;
  String _deviceName = 'LOCKER 01';
  LockDevice? _device;
  List<ActivityLogEntry> _activityLog = [];

  StreamSubscription<LockDevice>? _deviceSub;
  StreamSubscription<List<ActivityLogEntry>>? _historySub;

  // Navigation tab index:
  // 0: HISTORY (Left)
  // 1: LOCK (Middle - Circular with ring)
  // 2: SETTINGS (Right)
  int _currentNavIndex = 1;

  // Animation controller for tactile lock feedback
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Subscribe to live Firebase Realtime Database lock telemetry
    _deviceSub = LockService.instance.streamLock().listen((device) {
      if (mounted) {
        setState(() {
          _device = device;
          _isLocked = device.isLocked;
          _deviceName = device.name;
        });
      }
    });

    // Subscribe to live Firebase Realtime Database access history
    _historySub = LockService.instance.streamHistory().listen((entries) {
      if (mounted) {
        setState(() {
          _activityLog = entries;
        });
      }
    });
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _historySub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _toggleLockState({bool isBiometric = false}) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      _animController.forward().then((_) {
        _animController.reverse();
      });

      final targetState = !_isLocked;
      setState(() {
        _isLocked = targetState;
      });

      await LockService.instance.setLockState(
        targetState,
        isBiometric: isBiometric,
        userEmail: AuthService.instance.currentUserEmail,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0D141F),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
          ),
          content: Row(
            children: [
              Icon(
                _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: const Color(0xFF00D4FF),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                _isLocked
                    ? 'ARDUINO: LOCK ENGAGED'
                    : 'ARDUINO: LOCK RELEASED',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFFF1F5F9),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      } else {
        _isProcessing = false;
      }
    }
  }

  void _showDeviceRenameDialog() {
    final controller = TextEditingController(text: _deviceName);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D141F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF162232), width: 1),
          ),
          title: const Text(
            'RENAME DEVICE',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFFF1F5F9),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a custom identifier for this Arduino locker unit.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF7A889B),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF080C10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF162232)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13.5,
                    color: Color(0xFFF1F5F9),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  color: Color(0xFF7A889B),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                Navigator.pop(dialogContext);
                if (newName.isNotEmpty) {
                  setState(() {
                    _deviceName = newName.toUpperCase();
                  });
                  await LockService.instance.updateDeviceName(newName);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: const Color(0xFF080C10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'SAVE',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteSlot(int slotId, String label) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF0D141F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF162232)),
        ),
        title: const Text(
          'REMOVE FINGERPRINT',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Color(0xFFF1F5F9),
          ),
        ),
        content: Text(
          'Are you sure you want to remove "$label" (Slot #$slotId) from the ES608 sensor and Firebase?',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Color(0xFF7A889B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                color: Color(0xFF7A889B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await LockService.instance.deleteFingerprintSlot(slotId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'REMOVE',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceInformationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D141F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF162232), width: 1.2),
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
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.developer_board_rounded,
                  size: 18,
                  color: Color(0xFF00D4FF),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'DEVICE INFORMATION',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFFF1F5F9),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoDialogRow('Device Name', _device?.name ?? 'LOCKER 01'),
                const Divider(color: Color(0xFF162232), height: 16),
                _buildInfoDialogRow('Microcontroller', _device?.microcontroller ?? 'Arduino Nano ESP32'),
                const Divider(color: Color(0xFF162232), height: 16),
                _buildInfoDialogRow('Firmware Version', _device?.firmware ?? 'v2.4.1 (Latest)'),
                const Divider(color: Color(0xFF162232), height: 16),
                _buildInfoDialogRow('Target RTDB Node', '/lockers/locker_01'),
                const Divider(color: Color(0xFF162232), height: 16),
                _buildInfoDialogRow('Biometric Sensor', 'ES608 Optical Module'),
                const Divider(color: Color(0xFF162232), height: 16),
                _buildInfoDialogRow('Auto-Lock Timeout', '${_device?.autoLockTimeout ?? 30} Seconds'),
                const Divider(color: Color(0xFF162232), height: 16),
                _buildInfoDialogRow('UART Baud Rate', '${_device?.baudRate ?? 115200} bps'),
                const Divider(color: Color(0xFF162232), height: 16),
                _buildInfoDialogRow('Telemetry Stream', 'ESP32 Active / Connected', isHighlight: true),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                key: const Key('close_device_info_dialog_button'),
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  foregroundColor: const Color(0xFF080C10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'CLOSE',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0D141F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF162232), width: 1.2),
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
                      color: const Color(0xFF00D4FF).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 18,
                      color: Color(0xFF00D4FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'CHANGE PASSWORD',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Color(0xFFF1F5F9),
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
                      'Account: ${AuthService.instance.currentUserEmail ?? "operator@locksync.internal"}',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10.5,
                        color: Color(0xFF00D4FF),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // New Password Label
                    const Text(
                      'NEW PASSWORD',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                        color: Color(0xFF7A889B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF090E16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E2E42)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('change_password_new_input'),
                              controller: newPasswordController,
                              obscureText: obscureNew,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Color(0xFFF1F5F9),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: '6-digit passcode (Default: 123456)',
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Color(0xFF4A5C70),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                              color: const Color(0xFF7A889B),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureNew = !obscureNew;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Confirm Password Label
                    const Text(
                      'CONFIRM PASSWORD',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                        color: Color(0xFF7A889B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF090E16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E2E42)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('change_password_confirm_input'),
                              controller: confirmPasswordController,
                              obscureText: obscureConfirm,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Color(0xFFF1F5F9),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: 'Re-enter new password',
                                hintStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Color(0xFF4A5C70),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 18,
                              color: const Color(0xFF7A889B),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureConfirm = !obscureConfirm;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          color: Color(0xFFFF5252),
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
                        key: const Key('cancel_change_password_button'),
                        onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7A889B),
                          side: const BorderSide(color: Color(0xFF1E2E42)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('submit_change_password_button'),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final newPass = newPasswordController.text.trim();
                                final confirmPass = confirmPasswordController.text.trim();

                                if (newPass.length < 6) {
                                  setDialogState(() {
                                    errorMessage = 'Password must be at least 6 characters.';
                                  });
                                  return;
                                }
                                if (newPass != confirmPass) {
                                  setDialogState(() {
                                    errorMessage = 'Passwords do not match.';
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  isSubmitting = true;
                                  errorMessage = null;
                                });

                                final res = await AuthService.instance.updatePassword(newPass);

                                if (!dialogContext.mounted) return;

                                if (!res.success) {
                                  setDialogState(() {
                                    isSubmitting = false;
                                    errorMessage = res.errorMessage ?? 'Failed to update password.';
                                  });
                                } else {
                                  Navigator.pop(dialogContext);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF0D141F),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: const BorderSide(color: Color(0xFF00D4FF), width: 1),
                                        ),
                                        content: const Row(
                                          children: [
                                            Icon(Icons.check_circle_rounded, color: Color(0xFF00D4FF), size: 18),
                                            SizedBox(width: 10),
                                            Text(
                                              'PASSWORD UPDATED SUCCESSFULLY',
                                              style: TextStyle(
                                                fontFamily: 'JetBrains Mono',
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFF1F5F9),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4FF),
                          foregroundColor: const Color(0xFF080C10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF080C10),
                                ),
                              )
                            : const Text(
                                'UPDATE',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C10),
      // Persistent Bottom Navigation Bar
      bottomNavigationBar: Container(
        height: 74,
        decoration: const BoxDecoration(
          color: Color(0xFF080C10),
          border: Border(
            top: BorderSide(
              color: Color(0xFF14202C),
              width: 1.0,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // 1. HISTORY TAB (ON LEFT SIDE)
              Expanded(
                child: _buildBottomNavItem(
                  index: 0,
                  icon: Icons.history_rounded,
                  label: 'HISTORY',
                  isSelected: _currentNavIndex == 0,
                  onTap: () => setState(() => _currentNavIndex = 0),
                ),
              ),

              // 2. LOCK TAB (IN THE MIDDLE - CIRCULAR WITH A RING AROUND IT)
              Expanded(
                child: _buildCircularMiddleNavItem(
                  isSelected: _currentNavIndex == 1,
                  onTap: () => setState(() => _currentNavIndex = 1),
                ),
              ),

              // 3. SETTINGS TAB (ON RIGHT SIDE)
              Expanded(
                child: _buildBottomNavItem(
                  index: 2,
                  icon: Icons.settings_outlined,
                  label: 'SETTINGS',
                  isSelected: _currentNavIndex == 2,
                  onTap: () => setState(() => _currentNavIndex = 2),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                _buildFixedTopHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildCurrentTabContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FIXED TOP HEADER (CENTERED WITH CAMERA CLEARANCE)
  // ==========================================
  Widget _buildFixedTopHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 26.0, // Pushed down to clear top-center camera cutout / punch hole
        bottom: 12.0,
        left: 20.0,
        right: 20.0,
      ),
      alignment: Alignment.center,
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.8,
          ),
          children: [
            TextSpan(
              text: 'LOCK',
              style: TextStyle(color: Color(0xFFF1F5F9)),
            ),
            TextSpan(
              text: 'SYNC',
              style: TextStyle(color: Color(0xFF00D4FF)),
            ),
          ],
        ),
      ),
    );
  }

  // Choose tab body
  Widget _buildCurrentTabContent() {
    switch (_currentNavIndex) {
      case 0:
        return _buildHistoryTabContent();
      case 2:
        return _buildSettingsTabContent();
      case 1:
      default:
        return _buildLockTabContent();
    }
  }

  // ==========================================
  // TAB 1: MAIN LOCK CONTROL (CENTER FOCUS, NO HISTORY)
  // ==========================================
  Widget _buildLockTabContent() {
    return SingleChildScrollView(
      key: const ValueKey('lock_tab_content'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Locker Identity
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONNECTED DEVICE',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: Color(0xFF6B7C93),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    _deviceName,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: Color(0xFFF1F5F9),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _showDeviceRenameDialog,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Color(0xFF00D4FF),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Arduino Smart Lock',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF7A889B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // 3. Main Interactive Circular Lock with Concentric Ring
          Center(
            child: GestureDetector(
              key: const Key('main_lock_circle_button'),
              onTap: () => _toggleLockState(isBiometric: false),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: 224,
                  height: 224,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF080C10),
                    // Thin outer boundary border
                    border: Border.all(
                      color: const Color(0xFF14202C),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D4FF).withOpacity(
                          _isLocked ? 0.16 : 0.32,
                        ),
                        blurRadius: _isLocked ? 38 : 46,
                        spreadRadius: _isLocked ? 2 : 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Concentric Ring 2: Active Outer Track
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        width: 206,
                        height: 206,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isLocked
                                ? const Color(0xFF00D4FF).withOpacity(0.55)
                                : const Color(0xFF00D4FF),
                            width: _isLocked ? 1.5 : 2.0,
                          ),
                        ),
                      ),

                      // Concentric Ring 3: Hairline inner boundary
                      Container(
                        width: 174,
                        height: 174,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF142232),
                            width: 1.0,
                          ),
                        ),
                      ),

                      // Concentric Ring 4: Inner Core Elevated Disk
                      Container(
                        width: 152,
                        height: 152,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0B121A),
                          border: Border.all(
                            color: const Color(0xFF1A2838),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Animated Padlock Icon
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(
                                scale: anim,
                                child: child,
                              ),
                              child: Icon(
                                _isLocked
                                    ? Icons.lock_rounded
                                    : Icons.lock_open_rounded,
                                key: ValueKey<bool>(_isLocked),
                                size: 44,
                                color: const Color(0xFF00D4FF),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Status Heading
                            Text(
                              _isLocked ? 'LOCKED' : 'UNLOCKED',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.2,
                                color: _isLocked
                                    ? const Color(0xFFF1F5F9)
                                    : const Color(0xFF00D4FF),
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Instruction Label
                            Text(
                              _isLocked ? 'TAP TO UNLOCK' : 'TAP TO LOCK',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                                color: _isLocked
                                    ? const Color(0xFF6B7C93)
                                    : const Color(0xFF00D4FF).withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // 4. Device Status Panel (3 Columns)
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D141F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF162232),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                // COLUMN 1: SIGNAL
                Expanded(
                  child: _buildStatusColumn(
                    label: 'SIGNAL',
                    icon: Icons.wifi_rounded,
                    value: _device?.signal ?? 'STRONG',
                    valueColor: const Color(0xFFF1F5F9),
                  ),
                ),

                // Vertical Divider
                Container(
                  width: 1,
                  height: 36,
                  color: const Color(0xFF162232),
                ),

                // COLUMN 2: DEVICE
                Expanded(
                  child: _buildStatusColumn(
                    label: 'DEVICE',
                    icon: Icons.developer_board_rounded,
                    value: (_device?.isOnline ?? true) ? 'ONLINE' : 'OFFLINE',
                    valueColor: (_device?.isOnline ?? true)
                        ? const Color(0xFF00D4FF)
                        : const Color(0xFFFF5252),
                  ),
                ),

                // Vertical Divider
                Container(
                  width: 1,
                  height: 36,
                  color: const Color(0xFF162232),
                ),

                // COLUMN 3: STATE
                Expanded(
                  child: _buildStatusColumn(
                    label: 'STATE',
                    icon: _isLocked
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    value: _isLocked ? 'LOCKED' : 'OPEN',
                    valueColor: const Color(0xFF00D4FF),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // 5. Biometric Primary Button Action
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              key: const Key('primary_biometric_button'),
              onPressed: () => _toggleLockState(isBiometric: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: const Color(0xFF080C10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.zero,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isLocked
                            ? Icons.fingerprint_rounded
                            : Icons.lock_rounded,
                        size: 19,
                        color: const Color(0xFF080C10),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isLocked ? 'UNLOCK WITH BIOMETRICS' : 'LOCK DEVICE',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Color(0xFF080C10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 0: ACCESS HISTORY SCREEN (ON LEFT SIDE)
  // ==========================================
  Widget _buildHistoryTabContent() {
    return Column(
      key: const ValueKey('history_tab_content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 14.0),
          child: Text(
            'HISTORY LOG',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: Color(0xFFF1F5F9),
            ),
          ),
        ),
        const Divider(color: Color(0xFF162232), height: 1),
        Expanded(
          child: _activityLog.isEmpty
              ? const Center(
                  child: Text(
                    'No access history recorded yet.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Color(0xFF6B7C93),
                    ),
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  itemCount: _activityLog.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final event = _activityLog[index];
                    final isUnlock = event.isUnlock;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090F17),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF162232),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D4FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isUnlock
                                  ? Icons.lock_open_rounded
                                  : Icons.lock_rounded,
                              color: const Color(0xFF00D4FF),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  event.subtitle,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.5,
                                    color: Color(0xFF7A889B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            event.formattedTime,
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: Color(0xFF5A6B80),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: SETTINGS SCREEN (ON RIGHT SIDE)
  // ==========================================
  Widget _buildSettingsTabContent() {
    return SingleChildScrollView(
      key: const ValueKey('settings_tab_content'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEVICE SETTINGS',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hardware telemetry and access security configurations.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: Color(0xFF7A889B),
            ),
          ),
          const SizedBox(height: 18),

          // 1. Device Information Button
          _buildSettingsMenuButton(
            key: const Key('device_information_button'),
            icon: Icons.info_outline_rounded,
            title: 'DEVICE INFORMATION',
            subtitle: 'Microcontroller, firmware & connection node',
            onTap: _showDeviceInformationDialog,
          ),
          const SizedBox(height: 12),

          // 2. Change Password Button
          _buildSettingsMenuButton(
            key: const Key('change_password_button'),
            icon: Icons.lock_reset_rounded,
            title: 'CHANGE PASSWORD',
            subtitle: 'Update master credentials for your account',
            onTap: _showChangePasswordDialog,
          ),

          const SizedBox(height: 24),

          // ==========================================
          // BIOMETRIC MANAGEMENT SECTION (ES608)
          // ==========================================
          const Text(
            'BIOMETRIC CREDENTIALS',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage authorized fingerprint templates stored on ES608 sensor.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: Color(0xFF7A889B),
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D141F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF162232)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'REGISTERED FINGERPRINTS',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Color(0xFF7A889B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_device?.registeredSlots.length ?? 0} / 5 SLOTS',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF00D4FF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_device?.registeredSlots.isEmpty ?? true)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'No fingerprints registered yet.\nTap below to enroll your first biometric credential.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          color: Color(0xFF6B7C93),
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _device!.registeredSlots.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: Color(0xFF162232),
                      height: 16,
                    ),
                    itemBuilder: (context, index) {
                      final slot = _device!.registeredSlots.values.elementAt(index);
                      return Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D4FF).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.fingerprint_rounded,
                              size: 20,
                              color: Color(0xFF00D4FF),
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
                                        slot.label,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFF1F5F9),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF142232),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'SLOT #${slot.slotId}',
                                        style: const TextStyle(
                                          fontFamily: 'JetBrains Mono',
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF00D4FF),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  slot.formattedDate,
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 10,
                                    color: Color(0xFF6B7C93),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            color: const Color(0xFFFF5252).withOpacity(0.8),
                            tooltip: 'Delete Slot',
                            onPressed: () => _confirmDeleteSlot(slot.slotId, slot.label),
                          ),
                        ],
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // Button to launch enrollment modal
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('enroll_fingerprint_button'),
                    onPressed: () => showFingerprintEnrollmentModal(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      foregroundColor: const Color(0xFF080C10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'ENROLL NEW FINGERPRINT',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () async {
                await AuthService.instance.signOut();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MobileLandingScreen()),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF5252),
                side: const BorderSide(
                  color: Color(0xFFFF5252),
                  width: 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'DISCONNECT & SIGN OUT',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
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

  static Widget _buildStatusColumn({
    required String label,
    required IconData icon,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: Color(0xFF6B7C93),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: valueColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: valueColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsMenuButton({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: const Color(0xFF00D4FF).withValues(alpha: 0.12),
        highlightColor: const Color(0xFF00D4FF).withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0D141F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF162232)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF142232),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E2E42)),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF00D4FF),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: Color(0xFF7A889B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Color(0xFF4A5C70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildInfoDialogRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFF7A889B),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isHighlight ? const Color(0xFF00E676) : const Color(0xFFF1F5F9),
            ),
          ),
        ),
      ],
    );
  }

  // Standard Bottom Nav Item for History (Left) and Settings (Right)
  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeColor = const Color(0xFF00D4FF);
    final inactiveColor = const Color(0xFF6B7C93);

    return InkWell(
      key: Key('bottom_nav_$label'),
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? activeColor : inactiveColor,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.2,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }

  // Circular Middle Button with Ring Around It (LOCK in the middle)
  Widget _buildCircularMiddleNavItem({
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: const Key('bottom_nav_LOCK_circular'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular button with a cyan ring around it
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0B121A),
              border: Border.all(
                color: const Color(0xFF00D4FF),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D4FF).withOpacity(
                    isSelected ? 0.45 : 0.20,
                  ),
                  blurRadius: isSelected ? 14 : 8,
                  spreadRadius: isSelected ? 1.5 : 0.5,
                ),
              ],
            ),
            child: Icon(
              _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 20,
              color: const Color(0xFF00D4FF),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'LOCK',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.2,
              color: isSelected
                  ? const Color(0xFF00D4FF)
                  : const Color(0xFF6B7C93),
            ),
          ),
        ],
      ),
    );
  }
}
