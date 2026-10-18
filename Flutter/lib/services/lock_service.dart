import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/lock_model.dart';
import 'firebase_service.dart';

class LockService {
  static final LockService _instance = LockService._internal();
  factory LockService() => _instance;
  static LockService get instance => _instance;

  LockService._internal() {
    _initFallbackState();
  }

  static const String defaultLockId = 'locker_01';

  // Fallback / in-memory reactive state
  late LockDevice _currentDevice;
  final List<ActivityLogEntry> _historyEntries = [];
  final StreamController<LockDevice> _deviceStreamController =
      StreamController<LockDevice>.broadcast();
  final StreamController<List<ActivityLogEntry>> _historyStreamController =
      StreamController<List<ActivityLogEntry>>.broadcast();
  final StreamController<EnrollmentTelemetry> _enrollmentStreamController =
      StreamController<EnrollmentTelemetry>.broadcast();

  Timer? _simulationTimer1;
  Timer? _simulationTimer2;
  Timer? _simulationTimer3;
  Timer? _simulationTimer4;
  Timer? _simulationTimer5;

  void _initFallbackState() {
    final now = DateTime.now();

    final initialSlots = <String, FingerprintSlot>{
      'slot_1': FingerprintSlot(
        slotId: 1,
        label: 'Right Thumb',
        assignedUser: 'USER_2026_ST99',
        registeredAt: now.subtract(const Duration(days: 3)),
        workflowId: 'enroll_sess_20261014_001',
      ),
    };

    _currentDevice = LockDevice(
      id: defaultLockId,
      name: 'LOCKER 01',
      isLocked: true,
      isOnline: true,
      signal: 'STRONG',
      battery: 98,
      autoLockTimeout: 30,
      microcontroller: 'Arduino Nano ESP32',
      firmware: 'v2.4.1 (Latest)',
      baudRate: 115200,
      lastUpdated: now,
      updatedBy: 'System',
      doorOpen: false,
      tamperAlert: false,
      enrollStatus: EnrollStatus.idle,
      workflowId: null,
      lastAction: 'INITIALIZED',
      registeredSlots: initialSlots,
    );

    // Initial dynamic recent activity
    _historyEntries.addAll([
      ActivityLogEntry(
        id: 'evt_1',
        title: 'Locker unlocked',
        subtitle: 'Biometric access (Slot #1)',
        timestamp: now.subtract(const Duration(minutes: 18)),
        isUnlock: true,
        source: 'hardware',
      ),
      ActivityLogEntry(
        id: 'evt_2',
        title: 'Locker secured',
        subtitle: 'Auto-lock timer (30s)',
        timestamp: now.subtract(const Duration(hours: 2, minutes: 45)),
        isUnlock: false,
        source: 'hardware',
      ),
      ActivityLogEntry(
        id: 'evt_3',
        title: 'Locker secured',
        subtitle: 'Manual command via app',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        isUnlock: false,
        source: 'app',
      ),
      ActivityLogEntry(
        id: 'evt_4',
        title: 'Locker unlocked',
        subtitle: 'NFC Master Key',
        timestamp: now.subtract(const Duration(days: 1, hours: 7)),
        isUnlock: true,
        source: 'hardware',
      ),
      ActivityLogEntry(
        id: 'evt_5',
        title: 'System online',
        subtitle: 'Arduino ESP32 handshake',
        timestamp: now.subtract(const Duration(days: 1, hours: 14)),
        isUnlock: false,
        source: 'system',
      ),
    ]);
  }

  FirebaseDatabase? get _database {
    if (FirebaseService.isInitialized) {
      try {
        return FirebaseDatabase.instance;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  DatabaseReference? _lockRef([String lockId = defaultLockId]) {
    final cleanId = lockId.toLowerCase();
    return _database?.ref('lockers/$cleanId');
  }

  /// Real-time stream of lock status and hardware telemetry
  Stream<LockDevice> streamLock([String lockId = defaultLockId]) {
    final db = _database;
    if (db != null) {
      final cleanId = lockId.toLowerCase();
      return db.ref('lockers/$cleanId').onValue.map((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          return LockDevice.fromMap(lockId, val);
        }
        return _currentDevice;
      });
    }

    return Stream<LockDevice>.multi((controller) {
      controller.add(_currentDevice);
      final subscription = _deviceStreamController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => subscription.cancel();
    });
  }

  /// Real-time stream of audit history entries
  Stream<List<ActivityLogEntry>> streamHistory([String lockId = defaultLockId]) {
    final db = _database;
    if (db != null) {
      final cleanId = lockId.toLowerCase();
      return db.ref('lockers/$cleanId/history').onValue.map((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          final entries = <ActivityLogEntry>[];
          val.forEach((key, mapData) {
            if (mapData is Map) {
              entries.add(ActivityLogEntry.fromMap(key.toString(), mapData));
            }
          });
          entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return entries;
        }
        return List<ActivityLogEntry>.unmodifiable(_historyEntries);
      });
    }

    return Stream<List<ActivityLogEntry>>.multi((controller) {
      controller.add(List<ActivityLogEntry>.unmodifiable(_historyEntries));
      final subscription = _historyStreamController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => subscription.cancel();
    });
  }

  /// Real-time stream of biometric enrollment lifecycle telemetry
  Stream<EnrollmentTelemetry> streamEnrollment([String lockId = defaultLockId]) {
    final db = _database;
    if (db != null) {
      final cleanId = lockId.toLowerCase();
      return db.ref('lockers/$cleanId').onValue.map((event) {
        final val = event.snapshot.value;
        if (val is Map) {
          final statusStr = val['enrollStatus']?.toString();
          final workflowId = val['workflowId']?.toString();
          final lastAction = val['lastAction']?.toString();
          return EnrollmentTelemetry(
            status: EnrollStatus.fromString(statusStr),
            workflowId: workflowId,
            lastAction: lastAction,
          );
        }
        return EnrollmentTelemetry(
          status: _currentDevice.enrollStatus,
          workflowId: _currentDevice.workflowId,
          lastAction: _currentDevice.lastAction,
        );
      });
    }

    return Stream<EnrollmentTelemetry>.multi((controller) {
      controller.add(EnrollmentTelemetry(
        status: _currentDevice.enrollStatus,
        workflowId: _currentDevice.workflowId,
        lastAction: _currentDevice.lastAction,
      ));
      final subscription = _enrollmentStreamController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => subscription.cancel();
    });
  }

  /// Toggles or sets the lock state and pushes audit trail entry to Firebase
  Future<void> setLockState(
    bool isLocked, {
    String lockId = defaultLockId,
    bool isBiometric = false,
    String? userEmail,
  }) async {
    final now = DateTime.now();
    final trigger = isBiometric ? 'Biometric access' : 'LockSync app control';
    final actionTitle = isLocked ? 'Locker secured' : 'Locker unlocked';
    final workflowId = 'remote_cmd_${now.millisecondsSinceEpoch}';

    final ref = _lockRef(lockId);
    if (ref != null) {
      try {
        await ref.update({
          'isLocked': isLocked,
          'workflowId': workflowId,
          'lastAction': isLocked ? 'LOCKED_VIA_APP' : 'UNLOCKED_VIA_APP',
          'lastUpdated': ServerValue.timestamp,
          'updatedBy': userEmail ?? (isBiometric ? 'Biometrics' : 'App User'),
        });

        final historyRef = ref.child('history').push();
        await historyRef.set({
          'title': actionTitle,
          'subtitle': trigger,
          'timestamp': ServerValue.timestamp,
          'isUnlock': !isLocked,
          'source': isBiometric ? 'biometric' : 'app',
        });
        return;
      } catch (_) {
        // Fall through to in-memory state update
      }
    }

    _currentDevice = _currentDevice.copyWith(
      isLocked: isLocked,
      workflowId: workflowId,
      lastAction: isLocked ? 'LOCKED_VIA_APP' : 'UNLOCKED_VIA_APP',
      lastUpdated: now,
      updatedBy: userEmail ?? (isBiometric ? 'Biometrics' : 'App User'),
    );
    _deviceStreamController.add(_currentDevice);

    final newEvent = ActivityLogEntry(
      id: 'evt_${now.millisecondsSinceEpoch}',
      title: actionTitle,
      subtitle: trigger,
      timestamp: now,
      isUnlock: !isLocked,
      source: isBiometric ? 'biometric' : 'app',
    );
    _historyEntries.insert(0, newEvent);
    _historyStreamController.add(List.unmodifiable(_historyEntries));
  }

  /// Initiates biometric fingerprint enrollment workflow as specified in Section 1
  Future<String> startEnrollment({
    required String label,
    String? assignedUser,
    String lockId = defaultLockId,
  }) async {
    _cancelSimulationTimers();

    final now = DateTime.now();
    final workflowId = 'enroll_sess_${now.millisecondsSinceEpoch}';

    final ref = _lockRef(lockId);
    if (ref != null) {
      try {
        await ref.update({
          'enrollStatus': 'START_ENROLL',
          'workflowId': workflowId,
          'lastAction': 'ENROLLMENT_REQUESTED',
        });
        return workflowId;
      } catch (_) {}
    }

    // In-memory simulation pipeline for testing and fallback mode
    _currentDevice = _currentDevice.copyWith(
      enrollStatus: EnrollStatus.startEnroll,
      workflowId: workflowId,
      lastAction: 'ENROLLMENT_REQUESTED',
    );
    _emitCurrentEnrollment();

    // Step 2 Phase A: PLACE_FINGER_1 (AWAITING_FIRST_SCAN)
    _simulationTimer1 = Timer(const Duration(milliseconds: 900), () {
      _currentDevice = _currentDevice.copyWith(
        enrollStatus: EnrollStatus.placeFinger1,
        lastAction: 'AWAITING_FIRST_SCAN',
      );
      _emitCurrentEnrollment();

      // Step 2 Phase B: REMOVE_FINGER (FIRST_SCAN_CAPTURED)
      _simulationTimer2 = Timer(const Duration(milliseconds: 2200), () {
        _currentDevice = _currentDevice.copyWith(
          enrollStatus: EnrollStatus.removeFinger,
          lastAction: 'FIRST_SCAN_CAPTURED',
        );
        _emitCurrentEnrollment();

        // Step 2 Phase C: PLACE_FINGER_2 (AWAITING_SECOND_SCAN)
        _simulationTimer3 = Timer(const Duration(milliseconds: 1800), () {
          _currentDevice = _currentDevice.copyWith(
            enrollStatus: EnrollStatus.placeFinger2,
            lastAction: 'AWAITING_SECOND_SCAN',
          );
          _emitCurrentEnrollment();

          // Step 2 Phase D: PROCESSING (GENERATING_BIOMETRIC_MODEL)
          _simulationTimer4 = Timer(const Duration(milliseconds: 2000), () {
            _currentDevice = _currentDevice.copyWith(
              enrollStatus: EnrollStatus.processing,
              lastAction: 'GENERATING_BIOMETRIC_MODEL',
            );
            _emitCurrentEnrollment();

            // Step 3: COMPLETED (BIOMETRIC_ENROLLED_SLOT_X)
            _simulationTimer5 = Timer(const Duration(milliseconds: 1800), () {
              // Find next available slot ID
              int nextSlotId = 1;
              while (_currentDevice.registeredSlots.containsKey('slot_$nextSlotId')) {
                nextSlotId++;
              }

              final newSlot = FingerprintSlot(
                slotId: nextSlotId,
                label: label.trim().isNotEmpty ? label.trim() : 'Fingerprint $nextSlotId',
                assignedUser: assignedUser ?? 'USER_${now.year}_ST99',
                registeredAt: DateTime.now(),
                workflowId: workflowId,
              );

              final updatedSlots = Map<String, FingerprintSlot>.from(
                _currentDevice.registeredSlots,
              );
              updatedSlots['slot_$nextSlotId'] = newSlot;

              _currentDevice = _currentDevice.copyWith(
                enrollStatus: EnrollStatus.completed,
                lastAction: 'BIOMETRIC_ENROLLED_SLOT_$nextSlotId',
                registeredSlots: updatedSlots,
              );
              _emitCurrentEnrollment();
            });
          });
        });
      });
    });

    return workflowId;
  }

  /// Manually advance to next enrollment step (useful for instant interactive UI testing)
  void simulateAdvanceEnrollmentStep() {
    _cancelSimulationTimers();
    final current = _currentDevice.enrollStatus;

    if (current == EnrollStatus.startEnroll) {
      _currentDevice = _currentDevice.copyWith(
        enrollStatus: EnrollStatus.placeFinger1,
        lastAction: 'AWAITING_FIRST_SCAN',
      );
    } else if (current == EnrollStatus.placeFinger1) {
      _currentDevice = _currentDevice.copyWith(
        enrollStatus: EnrollStatus.removeFinger,
        lastAction: 'FIRST_SCAN_CAPTURED',
      );
    } else if (current == EnrollStatus.removeFinger) {
      _currentDevice = _currentDevice.copyWith(
        enrollStatus: EnrollStatus.placeFinger2,
        lastAction: 'AWAITING_SECOND_SCAN',
      );
    } else if (current == EnrollStatus.placeFinger2) {
      _currentDevice = _currentDevice.copyWith(
        enrollStatus: EnrollStatus.processing,
        lastAction: 'GENERATING_BIOMETRIC_MODEL',
      );
    } else if (current == EnrollStatus.processing) {
      int nextSlotId = 1;
      while (_currentDevice.registeredSlots.containsKey('slot_$nextSlotId')) {
        nextSlotId++;
      }
      final newSlot = FingerprintSlot(
        slotId: nextSlotId,
        label: 'Fingerprint $nextSlotId',
        assignedUser: 'OPERATOR',
        registeredAt: DateTime.now(),
        workflowId: _currentDevice.workflowId ?? 'enroll_manual',
      );
      final updatedSlots = Map<String, FingerprintSlot>.from(
        _currentDevice.registeredSlots,
      );
      updatedSlots['slot_$nextSlotId'] = newSlot;

      _currentDevice = _currentDevice.copyWith(
        enrollStatus: EnrollStatus.completed,
        lastAction: 'BIOMETRIC_ENROLLED_SLOT_$nextSlotId',
        registeredSlots: updatedSlots,
      );
    }
    _emitCurrentEnrollment();
  }

  /// Resets / Finalizes the active workflow state as specified in Section 5
  Future<void> finalizeOrResetWorkflow([String lockId = defaultLockId]) async {
    _cancelSimulationTimers();

    final ref = _lockRef(lockId);
    if (ref != null) {
      try {
        await ref.update({
          'enrollStatus': 'IDLE',
          'workflowId': null,
          'lastAction': 'WORKFLOW_FINALIZED',
        });
        return;
      } catch (_) {}
    }

    _currentDevice = _currentDevice.copyWith(
      enrollStatus: EnrollStatus.idle,
      workflowId: null,
      lastAction: 'WORKFLOW_FINALIZED',
    );
    _emitCurrentEnrollment();
  }

  /// Removes a fingerprint slot from Firebase RTDB and local memory
  Future<void> deleteFingerprintSlot(int slotId, [String lockId = defaultLockId]) async {
    final ref = _lockRef(lockId);
    if (ref != null) {
      try {
        await ref.child('registeredSlots/slot_$slotId').remove();
        return;
      } catch (_) {}
    }

    final updatedSlots = Map<String, FingerprintSlot>.from(
      _currentDevice.registeredSlots,
    );
    updatedSlots.remove('slot_$slotId');
    _currentDevice = _currentDevice.copyWith(registeredSlots: updatedSlots);
    _deviceStreamController.add(_currentDevice);
  }

  void _emitCurrentEnrollment() {
    _deviceStreamController.add(_currentDevice);
    _enrollmentStreamController.add(EnrollmentTelemetry(
      status: _currentDevice.enrollStatus,
      workflowId: _currentDevice.workflowId,
      lastAction: _currentDevice.lastAction,
    ));
  }

  void _cancelSimulationTimers() {
    _simulationTimer1?.cancel();
    _simulationTimer2?.cancel();
    _simulationTimer3?.cancel();
    _simulationTimer4?.cancel();
    _simulationTimer5?.cancel();
  }

  /// Renames the device in Firebase and broadcasts the update
  Future<void> updateDeviceName(
    String newName, [
    String lockId = defaultLockId,
  ]) async {
    final cleanName = newName.trim().toUpperCase();
    if (cleanName.isEmpty) return;

    final ref = _lockRef(lockId);
    if (ref != null) {
      try {
        await ref.update({'name': cleanName});
        return;
      } catch (_) {}
    }

    _currentDevice = _currentDevice.copyWith(name: cleanName);
    _deviceStreamController.add(_currentDevice);
  }

  /// Updates auto-lock timeout
  Future<void> updateAutoLockTimeout(
    int seconds, [
    String lockId = defaultLockId,
  ]) async {
    final ref = _lockRef(lockId);
    if (ref != null) {
      try {
        await ref.update({'autoLockTimeout': seconds});
        return;
      } catch (_) {}
    }

    _currentDevice = _currentDevice.copyWith(autoLockTimeout: seconds);
    _deviceStreamController.add(_currentDevice);
  }

  /// Checks system connectivity against Firebase Realtime Database
  Future<bool> checkSystemConnectivity([String lockId = defaultLockId]) async {
    final ref = _lockRef(lockId);
    if (ref != null) {
      try {
        final snapshot = await ref.child('status').get().timeout(
              const Duration(seconds: 4),
            );
        if (snapshot.exists) {
          final status = snapshot.value?.toString().toLowerCase();
          return status == 'online' || status == 'connected';
        }
      } catch (_) {
        return false;
      }
    }
    return _currentDevice.isOnline;
  }
}
