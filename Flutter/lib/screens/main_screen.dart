import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:locksyncie/constants/app_constants.dart';
import 'package:locksyncie/models/command_action.dart';
import 'package:locksyncie/screens/tabs/biometrics_tab.dart';
import 'package:locksyncie/screens/tabs/control_tab.dart';
import 'package:locksyncie/screens/tabs/logs_tab.dart';
import 'package:locksyncie/screens/tabs/settings_tab.dart';
import 'package:locksyncie/services/system_status_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final DatabaseReference _unauthorizedCountRef = FirebaseDatabase.instance.ref(
    'lockers/locker_01/status/unauthorizedAttempts',
  );

  final DatabaseReference _commandActionRef = FirebaseDatabase.instance.ref(
    'lockers/locker_01/command/action',
  );

  final SystemStatusService _systemStatusService = SystemStatusService.instance;

  StreamSubscription<DatabaseEvent>? _unauthorizedSubscription;
  StreamSubscription<DatabaseEvent>? _commandActionSubscription;

  int _unauthorizedCount = 0;
  int _currentCommandAction = CommandAction.idle.value;
  bool _isDisarming = false;

  final List<Widget> _pages = const [
    ControlTab(),
    BiometricsTab(),
    LogsTab(),
    SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _subscribeToDatabase();
  }

  void _subscribeToDatabase() {
    _unauthorizedSubscription = _unauthorizedCountRef.onValue.listen((event) {
      if (!mounted) return;

      final val = event.snapshot.value;

      setState(() {
        if (val != null && val is int) {
          _unauthorizedCount = val;
        } else {
          _unauthorizedCount = 0;
        }
      });
    });

    _commandActionSubscription = _commandActionRef.onValue.listen((event) {
      if (!mounted) return;
      final val = event.snapshot.value;
      setState(() {
        if (val != null && val is int) {
          _currentCommandAction = val;
        } else {
          _currentCommandAction = CommandAction.idle.value;
        }
        _isDisarming = false;
      });
    });
  }

  @override
  void dispose() {
    _unauthorizedSubscription?.cancel();
    _commandActionSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _disarmAlarm(bool isReachable) async {
    if (!isReachable ||
        _currentCommandAction != CommandAction.idle.value ||
        _isDisarming) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() => _isDisarming = true);

    try {
      await _commandActionRef.set(CommandAction.resetUnauthorizedAlarm.value);
    } catch (_) {
      if (mounted) {
        setState(() => _isDisarming = false);
      }
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    HapticFeedback.lightImpact();

    setState(() => _currentIndex = index);

    _pageController.animateToPage(
      index,
      duration: AppDimensions.animDurationStandard,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _systemStatusService.isReachableNotifier,
      builder: (context, isReachable, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderLogo(),
                _buildOfflineBanner(!isReachable),
                _buildUnauthorizedBanner(isReachable),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _pages,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ESP32 UNREACHABLE / OFFLINE BANNER
  // ---------------------------------------------------------------------------
  Widget _buildOfflineBanner(bool isOffline) {
    return AnimatedSwitcher(
      duration: AppDimensions.animDurationStandard,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: isOffline
          ? Container(
              key: const ValueKey<String>('offline_banner'),
              margin: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 4.0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(
                  color: AppColors.errorRed.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: AppColors.errorRed,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "TERMINAL UNREACHABLE",
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontMono,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.errorRed,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "ESP32 unit is offline. Check Wi-Fi connection or power.",
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontSans,
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey<String>('empty_offline_banner')),
    );
  }

  // ---------------------------------------------------------------------------
  // UNAUTHORIZED SECURITY ALERT BANNER
  // ---------------------------------------------------------------------------
  Widget _buildUnauthorizedBanner(bool isReachable) {
    final isCommandPending = _currentCommandAction != CommandAction.idle.value;
    final isDisarmDisabled = isCommandPending || _isDisarming || !isReachable;

    return AnimatedSwitcher(
      duration: AppDimensions.animDurationStandard,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: _unauthorizedCount > 0
          ? Container(
              key: const ValueKey<String>('unauthorized_banner'),
              margin: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 4.0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(
                  color: AppColors.errorRed.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.errorRed,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "UNAUTHORIZED ACCESS",
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontMono,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.errorRed,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isReachable
                              ? "$_unauthorizedCount invalid attempt${_unauthorizedCount > 1 ? 's' : ''} detected"
                              : "Terminal offline — cannot disarm",
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontSans,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSubtle.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: isDisarmDisabled
                        ? null
                        : () => _disarmAlarm(isReachable),
                    style: TextButton.styleFrom(
                      backgroundColor: isDisarmDisabled
                          ? AppColors.errorRed.withValues(alpha: 0.25)
                          : AppColors.errorRed,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSmall,
                        ),
                      ),
                    ),
                    child: _isDisarming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            "DISARM",
                            style: TextStyle(
                              fontFamily: AppTextStyles.fontMono,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDisarmDisabled
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey<String>('empty_banner')),
    );
  }

  Widget _buildHeaderLogo() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 24.0,
        top: 16.0,
        right: 24.0,
        bottom: 8.0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: RichText(
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
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderDivider, width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        enableFeedback: false,
        onTap: _onTabTapped,
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.cyanAccent,
        unselectedItemColor: AppColors.textSubtle,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedFontSize: 14,
        unselectedFontSize: 12,
        selectedIconTheme: const IconThemeData(size: 20),
        unselectedIconTheme: const IconThemeData(size: 16),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_outline_rounded),
            activeIcon: Icon(Icons.lock_rounded),
            label: 'Control',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fingerprint_rounded),
            activeIcon: Icon(Icons.fingerprint_rounded),
            label: 'Biometrics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.history_rounded),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}