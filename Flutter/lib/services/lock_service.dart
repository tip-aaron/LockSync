import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/lock_model.dart';
import 'firebase_service.dart';

abstract final class LockServiceConstants {
  static const String defaultLockId = 'locker_01';
  static const String lockersNode = 'lockers';
  static const String historyNode = 'history';
  static const String registeredSlotsNode = 'registeredSlots';
}

class LockService {
  static final LockService _instance = LockService._internal();
  factory LockService() => _instance;
  static LockService get instance => _instance;

  LockService._internal();

  DatabaseReference? _lockRef([
    String lockId = LockServiceConstants.defaultLockId,
  ]) {
    if (!FirebaseService.isInitialized) return null;
    try {
      final cleanId = lockId.toLowerCase();
      return FirebaseDatabase.instance.ref(
        '${LockServiceConstants.lockersNode}/$cleanId',
      );
    } catch (_) {
      return null;
    }
  }

  /// Pushes one audit entry under lockers/<id>/history.
  /// [build] receives the generated push key and the current time.
  Future<void> _writeHistory(
    DatabaseReference lockRef,
    ActionsHistory Function(String id, DateTime now) build,
  ) async {
    final now = DateTime.now();
    final historyRef = lockRef.child(LockServiceConstants.historyNode).push();
    final entry = build(
      historyRef.key ?? 'evt_${now.millisecondsSinceEpoch}',
      now,
    );
    await historyRef.set(entry.toMap());
  }

  /// Real-time stream of locker state directly from Firebase RTDB.
  /// Emits `null` when Firebase is initializing or data is unavailable (triggers UI loading state).
  Stream<LockDevice?> streamLock([
    String lockId = LockServiceConstants.defaultLockId,
  ]) {
    final ref = _lockRef(lockId);
    if (ref == null) {
      return Stream.value(null);
    }

    return ref.onValue.map((event) {
      final val = event.snapshot.value;
      if (val is Map) {
        return LockDevice.fromMap(lockId, val);
      }
      return null;
    });
  }

  /// Real-time stream of audit action history entries directly from Firebase RTDB.
  Stream<List<ActionsHistory>> streamHistory([
    String lockId = LockServiceConstants.defaultLockId,
  ]) {
    final ref = _lockRef(lockId);
    if (ref == null) {
      return Stream.value(const []);
    }

    return ref.child(LockServiceConstants.historyNode).onValue.map((event) {
      final val = event.snapshot.value;
      if (val is Map) {
        final entries = <ActionsHistory>[];
        val.forEach((key, mapData) {
          if (mapData is Map) {
            entries.add(ActionsHistory.fromMap(key.toString(), mapData));
          }
        });
        entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return entries;
      }
      return const [];
    });
  }

  /// Toggles the lock state indefinitely on Firebase RTDB
  Future<bool> toggleLock(
    bool currentLockState, {
    String lockId = LockServiceConstants.defaultLockId,
  }) async {
    final ref = _lockRef(lockId);
    if (ref == null) return false;

    final targetState = !currentLockState;
    final action = targetState ? Actions.REMOTE_LOCK : Actions.REMOTE_UNLOCK;

    try {
      await ref.update({'isLocked': targetState, 'lastAction': action.value});

      await _writeHistory(
        ref,
        (id, now) => StandardActionHistory(
          id: id,
          action: action,
          description: 'Remote trigger via LockSync app',
          timestamp: now,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes every entry under lockers/<id>/history.
  Future<bool> clearHistory([
    String lockId = LockServiceConstants.defaultLockId,
  ]) async {
    final ref = _lockRef(lockId);
    if (ref == null) return false;

    try {
      await ref.child(LockServiceConstants.historyNode).remove();
      return true;
    } catch (e) {
      debugPrint('clearHistory failed: $e');
      return false;
    }
  }

  /// Clears unauthorized attempt security alerts on Firebase RTDB
  Future<bool> disarmUnauthorizedAttempt({
    String lockId = LockServiceConstants.defaultLockId,
  }) async {
    final ref = _lockRef(lockId);
    if (ref == null) return false;

    const action = Actions.UNAUTHORIZED_ATTEMPT;

    try {
      await ref.update({
        'unauthorizedAttempt': false,
        'tamperAlert': false,
        'lastAction': action.value,
      });

      await _writeHistory(
        ref,
        (id, now) => StandardActionHistory(
          id: id,
          action: action,
          description: 'Unauthorized attempt alert disarmed by app',
          timestamp: now,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reserves a history key for a new enrollment session (synchronous).
  /// Returns null when Firebase isn't available.
  String? newEnrollmentSessionId([
    String lockId = LockServiceConstants.defaultLockId,
  ]) {
    return _lockRef(lockId)?.child(LockServiceConstants.historyNode).push().key;
  }

  /// Triggers hardware fingerprint enrollment directly on ESP32 via RTDB and
  /// opens a history session (one entry per attempt) seeded with START_ENROLL.
  /// The firmware should read `enrollLabel` and store it as the slot label.
  Future<bool> startEnrollment({
    required String sessionId,
    String label = 'Fingerprint',
    String lockId = LockServiceConstants.defaultLockId,
  }) async {
    final ref = _lockRef(lockId);
    if (ref == null) return false;

    const status = EnrollStatus.START_ENROLL;

    try {
      await ref.update({
        'enrollStatus': status.value,
        'enrollLabel': label,
        'lastAction': status.value,
      });
    } catch (e) {
      debugPrint('startEnrollment update failed: $e');
      return false;
    }

    // Separate try: a history failure must never block the enrollment itself.
    try {
      final sessionRef = ref.child(
        '${LockServiceConstants.historyNode}/$sessionId',
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final firstEventKey = sessionRef.child('events').push().key!;

      await sessionRef.set({
        'action': Actions.ENROLLMENT.value,
        'enrollStatus': status.value,
        'description': 'Enrollment for "$label"',
        'timestamp': nowMs,
        'events': {
          firstEventKey: {'status': status.value, 'timestamp': nowMs},
        },
      });
    } catch (e) {
      debugPrint('startEnrollment history write failed: $e');
    }

    return true;
  }

  /// Appends one status event to an enrollment session. Pass [slotID] when
  /// the enrollment completes.
  Future<bool> logEnrollmentEvent(
    String sessionId,
    EnrollStatus status, {
    int? slotID,
    String lockId = LockServiceConstants.defaultLockId,
  }) async {
    final ref = _lockRef(lockId);
    if (ref == null) return false;

    try {
      final sessionRef = ref.child(
        '${LockServiceConstants.historyNode}/$sessionId',
      );
      final eventKey = sessionRef.child('events').push().key!;

      // One multi-path update: new event + latest status (+ slot on completion).
      await sessionRef.update({
        'events/$eventKey': {
          'status': status.value,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        'enrollStatus': status.value,
        if (slotID != null) 'slotID': slotID,
      });
      return true;
    } catch (e) {
      debugPrint('logEnrollmentEvent failed: $e');
      return false;
    }
  }

  /// Resets active enrollment state back to IDLE
  Future<bool> finalizeOrResetWorkflow([
    String lockId = LockServiceConstants.defaultLockId,
  ]) async {
    final ref = _lockRef(lockId);
    if (ref == null) return false;

    const status = EnrollStatus.IDLE;

    try {
      await ref.update({
        'enrollStatus': status.value,
        'lastAction': Actions.ENROLLMENT.value,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Requests removal of a fingerprint slot on ESP32 memory and Firebase
  Future<bool> deleteFingerprintSlot(
    int slotID, [
    String lockId = LockServiceConstants.defaultLockId,
  ]) async {
    final ref = _lockRef(lockId);
    if (ref == null) return false;

    try {
      await ref
          .child('${LockServiceConstants.registeredSlotsNode}/slot_$slotID')
          .remove();

      await _writeHistory(
        ref,
        (id, now) => SlotActionHistory(
          id: id,
          action: Actions.SLOT_DELETED,
          slotID: slotID,
          description: 'Fingerprint slot #$slotID removed via LockSync app',
          timestamp: now,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Updates locker device display name
  Future<bool> updateDeviceName(
    String newName, [
    String lockId = LockServiceConstants.defaultLockId,
  ]) async {
    final cleanName = newName.trim().toUpperCase();
    if (cleanName.isEmpty) return false;

    final ref = _lockRef(lockId);
    if (ref == null) return false;

    try {
      await ref.update({'name': cleanName});
      return true;
    } catch (_) {
      return false;
    }
  }
}
