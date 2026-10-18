import 'package:intl/intl.dart';

enum EnrollStatus {
  idle,                 // IDLE
  startEnroll,          // START_ENROLL
  placeFinger1,         // PLACE_FINGER_1
  removeFinger,         // REMOVE_FINGER
  placeFinger2,         // PLACE_FINGER_2
  processing,           // PROCESSING
  completed,            // COMPLETED
  errorPrintsDontMatch, // ERROR_PRINTS_DONT_MATCH
  errorScanFailed,      // ERROR_SCAN_FAILED
  errorTimeout,         // ERROR_TIMEOUT
  unknown;

  static EnrollStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'IDLE':
        return EnrollStatus.idle;
      case 'START_ENROLL':
        return EnrollStatus.startEnroll;
      case 'PLACE_FINGER_1':
        return EnrollStatus.placeFinger1;
      case 'REMOVE_FINGER':
        return EnrollStatus.removeFinger;
      case 'PLACE_FINGER_2':
        return EnrollStatus.placeFinger2;
      case 'PROCESSING':
        return EnrollStatus.processing;
      case 'COMPLETED':
        return EnrollStatus.completed;
      case 'ERROR_PRINTS_DONT_MATCH':
        return EnrollStatus.errorPrintsDontMatch;
      case 'ERROR_SCAN_FAILED':
        return EnrollStatus.errorScanFailed;
      case 'ERROR_TIMEOUT':
        return EnrollStatus.errorTimeout;
      default:
        return EnrollStatus.unknown;
    }
  }

  String get asString {
    switch (this) {
      case EnrollStatus.idle:
        return 'IDLE';
      case EnrollStatus.startEnroll:
        return 'START_ENROLL';
      case EnrollStatus.placeFinger1:
        return 'PLACE_FINGER_1';
      case EnrollStatus.removeFinger:
        return 'REMOVE_FINGER';
      case EnrollStatus.placeFinger2:
        return 'PLACE_FINGER_2';
      case EnrollStatus.processing:
        return 'PROCESSING';
      case EnrollStatus.completed:
        return 'COMPLETED';
      case EnrollStatus.errorPrintsDontMatch:
        return 'ERROR_PRINTS_DONT_MATCH';
      case EnrollStatus.errorScanFailed:
        return 'ERROR_SCAN_FAILED';
      case EnrollStatus.errorTimeout:
        return 'ERROR_TIMEOUT';
      case EnrollStatus.unknown:
        return 'UNKNOWN';
    }
  }

  bool get isError =>
      this == EnrollStatus.errorPrintsDontMatch ||
      this == EnrollStatus.errorScanFailed ||
      this == EnrollStatus.errorTimeout;
}

class FingerprintSlot {
  final int slotId;
  final String label;
  final String assignedUser;
  final DateTime registeredAt;
  final String workflowId;

  const FingerprintSlot({
    required this.slotId,
    required this.label,
    required this.assignedUser,
    required this.registeredAt,
    required this.workflowId,
  });

  Map<String, dynamic> toMap() {
    return {
      'slotId': slotId,
      'label': label,
      'assignedUser': assignedUser,
      'registeredAt': registeredAt.millisecondsSinceEpoch ~/ 1000,
      'workflowId': workflowId,
    };
  }

  factory FingerprintSlot.fromMap(int slotId, Map<dynamic, dynamic> map) {
    DateTime parseTime(dynamic val) {
      if (val is int) {
        if (val < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(val * 1000);
        }
        return DateTime.fromMillisecondsSinceEpoch(val);
      }
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return FingerprintSlot(
      slotId: (map['slotId'] as num?)?.toInt() ?? slotId,
      label: map['label']?.toString() ?? 'Fingerprint $slotId',
      assignedUser: map['assignedUser']?.toString() ?? 'USER_UNKNOWN',
      registeredAt: parseTime(map['registeredAt']),
      workflowId: map['workflowId']?.toString() ?? '',
    );
  }

  String get formattedDate {
    return DateFormat('MMM d, yyyy • hh:mm a').format(registeredAt);
  }
}

class EnrollmentTelemetry {
  final EnrollStatus status;
  final String? workflowId;
  final String? lastAction;
  final String? errorMessage;
  final int? registeredSlotId;

  const EnrollmentTelemetry({
    required this.status,
    this.workflowId,
    this.lastAction,
    this.errorMessage,
    this.registeredSlotId,
  });
}

class LockDevice {
  final String id;
  final String name;
  final bool isLocked;
  final bool isOnline;
  final String signal;
  final int battery;
  final int autoLockTimeout;
  final String microcontroller;
  final String firmware;
  final int baudRate;
  final DateTime lastUpdated;
  final String updatedBy;
  final bool doorOpen;
  final bool tamperAlert;
  final EnrollStatus enrollStatus;
  final String? workflowId;
  final String? lastAction;
  final Map<String, FingerprintSlot> registeredSlots;

  const LockDevice({
    required this.id,
    required this.name,
    required this.isLocked,
    this.isOnline = true,
    this.signal = 'STRONG',
    this.battery = 98,
    this.autoLockTimeout = 30,
    this.microcontroller = 'Arduino Nano ESP32',
    this.firmware = 'v2.4.1 (Latest)',
    this.baudRate = 115200,
    required this.lastUpdated,
    this.updatedBy = 'System',
    this.doorOpen = false,
    this.tamperAlert = false,
    this.enrollStatus = EnrollStatus.idle,
    this.workflowId,
    this.lastAction = 'INITIALIZED',
    this.registeredSlots = const {},
  });

  LockDevice copyWith({
    String? id,
    String? name,
    bool? isLocked,
    bool? isOnline,
    String? signal,
    int? battery,
    int? autoLockTimeout,
    String? microcontroller,
    String? firmware,
    int? baudRate,
    DateTime? lastUpdated,
    String? updatedBy,
    bool? doorOpen,
    bool? tamperAlert,
    EnrollStatus? enrollStatus,
    String? workflowId,
    String? lastAction,
    Map<String, FingerprintSlot>? registeredSlots,
  }) {
    return LockDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      isLocked: isLocked ?? this.isLocked,
      isOnline: isOnline ?? this.isOnline,
      signal: signal ?? this.signal,
      battery: battery ?? this.battery,
      autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
      microcontroller: microcontroller ?? this.microcontroller,
      firmware: firmware ?? this.firmware,
      baudRate: baudRate ?? this.baudRate,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
      doorOpen: doorOpen ?? this.doorOpen,
      tamperAlert: tamperAlert ?? this.tamperAlert,
      enrollStatus: enrollStatus ?? this.enrollStatus,
      workflowId: workflowId ?? this.workflowId,
      lastAction: lastAction ?? this.lastAction,
      registeredSlots: registeredSlots ?? this.registeredSlots,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isLocked': isLocked,
      'isOnline': isOnline,
      'signal': signal,
      'battery': battery,
      'autoLockTimeout': autoLockTimeout,
      'microcontroller': microcontroller,
      'firmware': firmware,
      'baudRate': baudRate,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'updatedBy': updatedBy,
      'doorOpen': doorOpen,
      'tamperAlert': tamperAlert,
      'enrollStatus': enrollStatus.asString,
      'workflowId': workflowId,
      'lastAction': lastAction,
      'registeredSlots': registeredSlots.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  factory LockDevice.fromMap(String id, Map<dynamic, dynamic> map) {
    DateTime parseTime(dynamic val) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    final slots = <String, FingerprintSlot>{};
    if (map['registeredSlots'] is Map) {
      (map['registeredSlots'] as Map).forEach((k, v) {
        if (v is Map) {
          final slotId = (v['slotId'] as num?)?.toInt() ??
              int.tryParse(k.toString().replaceAll(RegExp(r'[^0-9]'), '')) ??
              1;
          slots[k.toString()] = FingerprintSlot.fromMap(slotId, v);
        }
      });
    }

    return LockDevice(
      id: id,
      name: map['name']?.toString() ?? 'LOCKER 01',
      isLocked: map['isLocked'] == null ? true : (map['isLocked'] as bool),
      isOnline: map['isOnline'] == null ? true : (map['isOnline'] as bool),
      signal: map['signal']?.toString() ?? 'STRONG',
      battery: (map['battery'] as num?)?.toInt() ?? 98,
      autoLockTimeout: (map['autoLockTimeout'] as num?)?.toInt() ?? 30,
      microcontroller:
          map['microcontroller']?.toString() ?? 'Arduino Nano ESP32',
      firmware: map['firmware']?.toString() ?? 'v2.4.1 (Latest)',
      baudRate: (map['baudRate'] as num?)?.toInt() ?? 115200,
      lastUpdated: parseTime(map['lastUpdated']),
      updatedBy: map['updatedBy']?.toString() ?? 'System',
      doorOpen: map['doorOpen'] == true,
      tamperAlert: map['tamperAlert'] == true,
      enrollStatus: EnrollStatus.fromString(map['enrollStatus']?.toString()),
      workflowId: map['workflowId']?.toString(),
      lastAction: map['lastAction']?.toString() ?? 'INITIALIZED',
      registeredSlots: slots,
    );
  }
}

class ActivityLogEntry {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final bool isUnlock;
  final String source;

  const ActivityLogEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.isUnlock,
    this.source = 'app',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isUnlock': isUnlock,
      'source': source,
    };
  }

  factory ActivityLogEntry.fromMap(String id, Map<dynamic, dynamic> map) {
    DateTime parseTime(dynamic val) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return ActivityLogEntry(
      id: id,
      title: map['title']?.toString() ?? 'Locker activity',
      subtitle: map['subtitle']?.toString() ?? 'Hardware event',
      timestamp: parseTime(map['timestamp']),
      isUnlock: map['isUnlock'] == null ? false : (map['isUnlock'] as bool),
      source: map['source']?.toString() ?? 'system',
    );
  }

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 45) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && now.day == timestamp.day) {
      return 'Today, ${DateFormat('hh:mm a').format(timestamp)}';
    } else if (diff.inDays <= 1 ||
        (diff.inHours < 48 && now.day - timestamp.day == 1)) {
      return 'Yesterday, ${DateFormat('hh:mm a').format(timestamp)}';
    } else {
      return DateFormat('MMM d, hh:mm a').format(timestamp);
    }
  }
}
