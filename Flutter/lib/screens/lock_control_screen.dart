import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/lock_model.dart';
import '../services/lock_service.dart';
import 'tabs/history_tab.dart';
import 'tabs/lock_tab.dart';
import 'tabs/settings_tab.dart';

class LockControlScreen extends StatefulWidget {
  const LockControlScreen({super.key});

  @override
  State<LockControlScreen> createState() => _LockControlScreenState();
}

class _LockControlScreenState extends State<LockControlScreen> {
  LockDevice? _device;
  List<ActionsHistory> _activityLog = const [];

  StreamSubscription<LockDevice?>? _deviceSub;
  StreamSubscription<List<ActionsHistory>>? _historySub;

  int _currentNavIndex = 1; // 0: HISTORY, 1: LOCK, 2: SETTINGS

  @override
  void initState() {
    super.initState();

    _deviceSub = LockService.instance.streamLock().listen((device) {
      if (mounted) setState(() => _device = device);
    });

    _historySub = LockService.instance.streamHistory().listen((entries) {
      if (mounted) setState(() => _activityLog = entries);
    });
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _historySub?.cancel();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError
            ? AppColors.errorBackground
            : AppColors.cardBackground,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          side: BorderSide(
            color: isError ? AppColors.errorRed : AppColors.cyanAccent,
            width: 1,
          ),
        ),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : (_device?.isLocked ?? true
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded),
              color: isError ? AppColors.errorRed : AppColors.cyanAccent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(
                fontFamily: AppTextStyles.fontMono,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppDimensions.animDurationFast,
                    child: switch (_currentNavIndex) {
                      0 => HistoryTab(
                        key: const ValueKey('history_tab'),
                        history: _device?.history ?? _activityLog,
                        onShowSnackBar: _showSnackBar,
                      ),
                      2 => SettingsTab(
                        key: const ValueKey('settings_tab'),
                        device: _device,
                        onShowSnackBar: _showSnackBar,
                      ),
                      _ => LockTab(
                        key: const ValueKey('lock_tab'),
                        device: _device,
                        onShowSnackBar: _showSnackBar,
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 26.0, bottom: 12.0),
      alignment: Alignment.center,
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          children: [
            TextSpan(
              text: AppStrings.appTitlePart1,
              style: AppTextStyles.logoWhite,
            ),
            TextSpan(
              text: AppStrings.appTitlePart2,
              style: AppTextStyles.logoCyan,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 74,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.borderDivider, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _buildBottomNavItem(
                icon: Icons.history_rounded,
                label: 'HISTORY',
                isSelected: _currentNavIndex == 0,
                onTap: () => setState(() => _currentNavIndex = 0),
              ),
            ),
            Expanded(
              child: _buildCircularMiddleNavItem(
                isSelected: _currentNavIndex == 1,
                onTap: () => setState(() => _currentNavIndex = 1),
              ),
            ),
            Expanded(
              child: _buildBottomNavItem(
                icon: Icons.settings_outlined,
                label: 'SETTINGS',
                isSelected: _currentNavIndex == 2,
                onTap: () => setState(() => _currentNavIndex = 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const activeColor = AppColors.cyanAccent;
    const inactiveColor = AppColors.textSubtle;

    return InkWell(
      key: Key('bottom_nav_$label'),
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: isSelected ? activeColor : inactiveColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
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

  Widget _buildCircularMiddleNavItem({
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isLocked = _device?.isLocked ?? true;

    return GestureDetector(
      key: const Key('bottom_nav_LOCK_circular'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBackground,
              border: Border.all(color: AppColors.cyanAccent, width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyanAccent.withValues(
                    alpha: isSelected ? 0.45 : 0.20,
                  ),
                  blurRadius: isSelected ? 14 : 8,
                  spreadRadius: isSelected ? 1.5 : 0.5,
                ),
              ],
            ),
            child: Icon(
              isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 20,
              color: AppColors.cyanAccent,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'LOCK',
            style: TextStyle(
              fontFamily: AppTextStyles.fontMono,
              fontSize: 9.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 1.2,
              color: isSelected ? AppColors.cyanAccent : AppColors.textSubtle,
            ),
          ),
        ],
      ),
    );
  }
}
