import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class SystemStatusService {
  SystemStatusService._internal() {
    _init();
  }

  static final SystemStatusService instance = SystemStatusService._internal();

  static const int _offlineThresholdMs = 10_000; // 10 seconds threshold

  final DatabaseReference _lastSeenRef = FirebaseDatabase.instance.ref(
    'system/last_seen',
  );

  StreamSubscription<DatabaseEvent>? _subscription;
  Timer? _checkTimer;

  final ValueNotifier<bool> isReachableNotifier = ValueNotifier<bool>(true);
  int _lastSeenEpochMs = 0;

  void _init() {
    _subscription = _lastSeenRef.onValue.listen((event) {
      final rawValue = event.snapshot.value;
      if (rawValue is num) {
        int timestamp = rawValue.toInt();
        if (timestamp < 10000000000) {
          timestamp *= 1000;
        }
        _lastSeenEpochMs = timestamp;
      }
      _evaluateReachability();
    });

    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _evaluateReachability();
    });
  }

  void _evaluateReachability() {
    if (_lastSeenEpochMs == 0) {
      isReachableNotifier.value = false;
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isOnline = (nowMs - _lastSeenEpochMs) <= _offlineThresholdMs;

    if (isReachableNotifier.value != isOnline) {
      isReachableNotifier.value = isOnline;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _checkTimer?.cancel();
    isReachableNotifier.dispose();
  }
}
