#pragma once
#include <Arduino.h>

namespace constants {
// Compile-time Firebase Configs
constexpr const char *FIREBASE_HOST =
    "https://locksync-ab6fa-default-rtdb.asia-southeast1.firebasedatabase.app";
constexpr const char *FIREBASE_AUTH = "AIzaSyCwXNa8Ki40gn8W3_QdC6dbiIRkJsILGxA";

// DB Target Paths (Targeting primitive leaves avoids parsing massive JSON
// objects)
constexpr const char *DB_PATH_CMD_ACTION = "/lockers/locker_01/command/action";
constexpr const char *DB_PATH_CMD_PARAM = "/lockers/locker_01/command/param";

// Outbound Status Nodes
constexpr const char *DB_PATH_LOCK_STATUS =
    "/lockers/locker_01/status/isLocked";
constexpr const char *DB_PATH_ENROLL_STATUS =
    "/lockers/locker_01/status/enrollmentStatus";
constexpr const char *DB_PATH_UNAUTHORIZED_COUNT =
    "/lockers/locker_01/status/unauthorizedAttempts";

constexpr const char *DB_PATH_SYSTEM_LOGS = "/lockers/locker_01/logs";

// Buffer Limits
constexpr size_t FIREBASE_STREAM_BUFFER_SIZE = 2048; // 1 KB max response buffer

constexpr size_t MAX_PENDING_LOGS = 5;
constexpr size_t MAX_LOG_EVENT_LEN = 48;

enum class CommandAction : int {
  IDLE = 0,
  LOCK = 1,
  UNLOCK = 2,
  ENROLL_FINGERPRINT = 3,
  DELETE_FINGERPRINT = 4,
  CANCEL_ENROLLMENT = 5,
  RESET_UNAUTHORIZED = 6
};

constexpr char DB_PATH_HEARTBEAT[] = "/system/last_seen";
// Non-blocking ping interval (10,000 ms = 10 seconds)
// Balances quick offline detection in mobile clients without flooding SSL
// sockets
constexpr uint32_t HEARTBEAT_INTERVAL_MS = 5000;
} // namespace constants