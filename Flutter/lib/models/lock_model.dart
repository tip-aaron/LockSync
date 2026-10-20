import 'package:intl/intl.dart';

enum Actions {
  LOCK("LOCK"),
  UNLOCK("UNLOCK"),
  REMOTE_LOCK("REMOTE_LOCK"),
  REMOTE_UNLOCK("REMOTE_UNLOCK"),
  ENROLLMENT("ENROLLMENT"),
  SLOT_DELETED("SLOT_DELETED"),
  MOTION_DETECTED("MOTION_DETECTED"),
  UNAUTHORIZED_ATTEMPT("UNAUTHORIZED_ATTEMPT"),
  UNKNOWN("UNKNOWN");

  final String value;

  const Actions(this.value);

  static Actions fromString(String label) {
    return Actions.values.firstWhere(
      (v) => v.value.toLowerCase() == label.toLowerCase(),
      orElse: () => Actions.UNKNOWN,
    );
  }
}

enum EnrollStatus {
  IDLE("IDLE"),
  START_ENROLL("START_ENROLL"),
  PLACE_FINGER_1("PLACE_FINGER_1"),
  REMOVE_FINGER("REMOVE_FINGER"),
  PLACE_FINGER_2("PLACE_FINGER_2"),
  PROCESSING("PROCESSING"),
  COMPLETED("COMPLETED"),
  TIMEOUT("TIMEOUT"),
  CANCELED("CANCELED"),
  ERROR_STORAGE_FAILED("ERROR_STORAGE_FAILED"),
  ERROR_PRINTS_DONT_MATCH("ERROR_PRINTS_DONT_MATCH"),
  ERROR_SCAN_FAILED("ERROR_SCAN_FAILED"),
  UNKNOWN("UNKNOWN");

  final String value;

  const EnrollStatus(this.value);

  static EnrollStatus fromString(String label) {
    return EnrollStatus.values.firstWhere(
      (v) => v.value.toLowerCase() == label.toLowerCase(),
      orElse: () => EnrollStatus.UNKNOWN,
    );
  }
}

/// Parses RTDB timestamps: epoch seconds, epoch millis or ISO-8601 strings.
DateTime parseHistoryTime(dynamic val) {
  if (val is int) {
    if (val < 10_000_000_000) {
      return DateTime.fromMillisecondsSinceEpoch(val * 1_000);
    }
    return DateTime.fromMillisecondsSinceEpoch(val);
  }

  if (val is String) {
    final parsed = DateTime.tryParse(val);
    if (parsed != null) {
      return parsed;
    }
  }

  return DateTime.now();
}

class FingerprintSlot {
  final int slotID;
  final String label;
  final DateTime registeredAt;

  const FingerprintSlot({
    required this.slotID,
    required this.label,
    required this.registeredAt,
  });

  factory FingerprintSlot.fromMap(int slotID, Map<dynamic, dynamic> map) {
    return FingerprintSlot(
      slotID: (map["slotID"] as num?)?.toInt() ?? slotID,
      label: map["label"]?.toString() ?? "Fingerprint $slotID",
      registeredAt: parseHistoryTime(map["registeredAt"]),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "slotID": slotID,
      "label": label,
      "registeredAt": registeredAt.millisecondsSinceEpoch ~/ 1_000,
    };
  }
}

/// One status transition inside an enrollment session.
class EnrollmentEvent {
  final EnrollStatus status;
  final DateTime timestamp;

  const EnrollmentEvent({required this.status, required this.timestamp});

  factory EnrollmentEvent.fromMap(Map<dynamic, dynamic> map) {
    return EnrollmentEvent(
      status: EnrollStatus.fromString(map["status"]?.toString() ?? ""),
      timestamp: parseHistoryTime(map["timestamp"]),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "status": status.value,
      "timestamp": timestamp.millisecondsSinceEpoch,
    };
  }
}

// ============================================================================
// SEALED CLASS HIERARCHY PATTERN (ZERO NULLABLE FIELDS)
// ============================================================================

sealed class ActionsHistory {
  final String id;
  final Actions action;
  final String description;
  final DateTime timestamp;

  const ActionsHistory({
    required this.id,
    required this.action,
    required this.description,
    required this.timestamp,
  });

  factory ActionsHistory.fromMap(String id, Map<dynamic, dynamic> map) {
    final rawAction =
        map["action"]?.toString() ?? map["title"]?.toString() ?? "UNKNOWN";
    final parsedAction = Actions.fromString(rawAction);
    final parsedTimestamp = parseHistoryTime(map["timestamp"]);
    final parsedDescription = map["description"]?.toString() ??
        map["subtitle"]?.toString() ??
        map["lastAction"]?.toString() ??
        "";

    final rawEnrollStatus = map["enrollStatus"]?.toString() ?? "";
    final hasEnrollStatus =
        rawEnrollStatus.isNotEmpty || parsedAction == Actions.ENROLLMENT;
    final parsedSlotID =
        (map["slotID"] as num?)?.toInt() ?? (map["slotId"] as num?)?.toInt();

    // Enrollment session: one entry holding every status event of the attempt.
    final rawEvents = map["events"];
    if (parsedAction == Actions.ENROLLMENT && rawEvents is Map) {
      final events = rawEvents.values
          .whereType<Map>()
          .map(EnrollmentEvent.fromMap)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return EnrollmentSessionHistory(
        id: id,
        action: parsedAction,
        enrollStatus: EnrollStatus.fromString(rawEnrollStatus),
        slotID: parsedSlotID,
        events: events,
        description: parsedDescription,
        timestamp: parsedTimestamp,
      );
    }

    if (hasEnrollStatus && parsedSlotID != null) {
      return EnrollmentSlotActionHistory(
        id: id,
        action: parsedAction,
        enrollStatus: EnrollStatus.fromString(rawEnrollStatus),
        slotID: parsedSlotID,
        description: parsedDescription,
        timestamp: parsedTimestamp,
      );
    } else if (hasEnrollStatus) {
      return EnrollmentActionHistory(
        id: id,
        action: parsedAction,
        enrollStatus: EnrollStatus.fromString(rawEnrollStatus),
        description: parsedDescription,
        timestamp: parsedTimestamp,
      );
    } else if (parsedSlotID != null) {
      return SlotActionHistory(
        id: id,
        action: parsedAction,
        slotID: parsedSlotID,
        description: parsedDescription,
        timestamp: parsedTimestamp,
      );
    } else {
      return StandardActionHistory(
        id: id,
        action: parsedAction,
        description: parsedDescription,
        timestamp: parsedTimestamp,
      );
    }
  }

  Map<String, dynamic> toMap();

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 45) {
      return "Just now";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24 && now.day == timestamp.day) {
      return "Today, ${DateFormat('hh:mm a').format(timestamp)}";
    } else {
      return DateFormat('MMM d, hh:mm a').format(timestamp);
    }
  }
}

/// Variant 1: Standard hardware events (Lock, Unlock, Motion, Unauthorized)
final class StandardActionHistory extends ActionsHistory {
  const StandardActionHistory({
    required super.id,
    required super.action,
    required super.description,
    required super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "action": action.value,
      "description": description,
      "timestamp": timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Variant 2: Biometric enrollment lifecycle status updates
final class EnrollmentActionHistory extends ActionsHistory {
  final EnrollStatus enrollStatus;

  const EnrollmentActionHistory({
    required super.id,
    required super.action,
    required this.enrollStatus,
    required super.description,
    required super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "action": action.value,
      "enrollStatus": enrollStatus.value,
      "description": description,
      "timestamp": timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Variant 3: Fingerprint memory slot operations (Deletion / Selection)
final class SlotActionHistory extends ActionsHistory {
  final int slotID;

  const SlotActionHistory({
    required super.id,
    required super.action,
    required this.slotID,
    required super.description,
    required super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "action": action.value,
      "slotID": slotID,
      "description": description,
      "timestamp": timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Variant 4: Completed enrollment actions attached directly to a specific slot
final class EnrollmentSlotActionHistory extends ActionsHistory {
  final EnrollStatus enrollStatus;
  final int slotID;

  const EnrollmentSlotActionHistory({
    required super.id,
    required super.action,
    required this.enrollStatus,
    required this.slotID,
    required super.description,
    required super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "action": action.value,
      "enrollStatus": enrollStatus.value,
      "slotID": slotID,
      "description": description,
      "timestamp": timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Variant 5: One enrollment attempt with all of its status events.
final class EnrollmentSessionHistory extends ActionsHistory {
  final EnrollStatus enrollStatus; // latest status of the attempt
  final int? slotID; // set once enrollment completes
  final List<EnrollmentEvent> events; // oldest first

  const EnrollmentSessionHistory({
    required super.id,
    required super.action,
    required this.enrollStatus,
    required this.slotID,
    required this.events,
    required super.description,
    required super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "action": action.value,
      "enrollStatus": enrollStatus.value,
      if (slotID != null) "slotID": slotID,
      "description": description,
      "timestamp": timestamp.millisecondsSinceEpoch,
      "events": {
        for (var i = 0; i < events.length; i++) "evt_$i": events[i].toMap(),
      },
    };
  }
}

// ============================================================================
// DEVICE AGGREGATE ROOT MODEL
// ============================================================================

class LockDevice {
  final String ID;
  final String name;
  final bool isLocked;
  final bool motionDetected;
  final bool unauthorizedAttempt;
  final EnrollStatus enrollStatus;
  final String lastAction;
  final Map<String, FingerprintSlot> registeredSlots;
  final List<ActionsHistory> history;

  const LockDevice({
    required this.ID,
    required this.name,
    required this.isLocked,
    this.motionDetected = false,
    this.unauthorizedAttempt = false,
    this.enrollStatus = EnrollStatus.IDLE,
    this.lastAction = "INITIALIZED",
    this.registeredSlots = const {},
    this.history = const [],
  });

  factory LockDevice.fromMap(String id, Map<dynamic, dynamic> map) {
    final slots = <String, FingerprintSlot>{};
    if (map["registeredSlots"] is Map) {
      (map["registeredSlots"] as Map).forEach((k, v) {
        if (v is Map) {
          final slotID = (v["slotID"] as num?)?.toInt() ??
              (v["slotId"] as num?)?.toInt() ??
              int.tryParse(k.toString().replaceAll(RegExp(r'[^0-9]'), '')) ??
              1;
          slots[k.toString()] = FingerprintSlot.fromMap(slotID, v);
        }
      });
    }

    final historyList = <ActionsHistory>[];
    if (map["history"] is Map) {
      (map["history"] as Map).forEach((k, v) {
        if (v is Map) {
          historyList.add(ActionsHistory.fromMap(k.toString(), v));
        }
      });

      historyList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    return LockDevice(
      ID: id,
      name: map["name"]?.toString() ?? "LOCKER 01",
      isLocked: map["isLocked"] == null ? true : (map["isLocked"] as bool),
      motionDetected: map["motionDetected"] == true,
      unauthorizedAttempt: map["unauthorizedAttempt"] == true ||
          map["unauthorizedAccess"] == true ||
          map["tamperAlert"] == true,
      enrollStatus:
          EnrollStatus.fromString(map["enrollStatus"]?.toString() ?? ""),
      lastAction: map["lastAction"]?.toString() ?? "None",
      registeredSlots: slots,
      history: historyList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "ID": ID,
      "name": name,
      "isLocked": isLocked,
      "motionDetected": motionDetected,
      "unauthorizedAttempt": unauthorizedAttempt,
      "enrollStatus": enrollStatus.value,
      "lastAction": lastAction,
      "registeredSlots": registeredSlots.map((k, v) => MapEntry(k, v.toMap())),
      // Keyed by push id (not a list) so RTDB round-trips it as a Map.
      "history": {for (final e in history) e.id: e.toMap()},
    };
  }
}
