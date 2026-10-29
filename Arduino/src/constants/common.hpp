#pragma once

#include <cstdint>

namespace constants {
constexpr uint32_t SERIAL_BAUD = 115200;

constexpr uint32_t LOOP_DELAY_MS = 2;

enum class LogEvent {
  REMOTE_LOCKED,
  REMOTE_UNLOCKED,
  FINGERPRINT_ENROLLED,
  FINGERPRINT_ENROLLMENT_FAILED,
  FINGERPRINT_ENROLLMENT_CANCELLED,
  FINGERPRINT_ENROLLMENT_STARTED,
  FINGERPRINT_FIRST_SCAN_COMPLETE,
  FINGERPRINT_SECOND_SCAN_COMPLETE,
  FINGERPRINT_UNLOCKED,
  PHYSICAL_BUTTON_LOCKED,
  ALL_FINGERPRINTS_DELETED,
  ALARM_DISARMED,
  UNAUTHORIZED_ATTEMPT
};

inline const char *logEventToString(LogEvent event) {
  switch (event) {
  case LogEvent::REMOTE_LOCKED:
    return "REMOTE_LOCKED";
  case LogEvent::REMOTE_UNLOCKED:
    return "REMOTE_UNLOCKED";
  case LogEvent::FINGERPRINT_ENROLLED:
    return "FINGERPRINT_ENROLLED";
  case LogEvent::FINGERPRINT_ENROLLMENT_FAILED:
    return "FINGERPRINT_ENROLLMENT_FAILED";
  case LogEvent::FINGERPRINT_ENROLLMENT_CANCELLED:
    return "FINGERPRINT_ENROLLMENT_CANCELLED";
  case LogEvent::FINGERPRINT_ENROLLMENT_STARTED:
    return "FINGERPRINT_ENROLLMENT_STARTED";
  case LogEvent::FINGERPRINT_FIRST_SCAN_COMPLETE:
    return "FINGERPRINT_FIRST_SCAN_COMPLETE";
  case LogEvent::FINGERPRINT_SECOND_SCAN_COMPLETE:
    return "FINGERPRINT_SECOND_SCAN_COMPLETE";
  case LogEvent::ALL_FINGERPRINTS_DELETED:
    return "ALL_FINGERPRINTS_DELETED";
  case LogEvent::FINGERPRINT_UNLOCKED:
    return "FINGERPRINT_UNLOCKED";
  case LogEvent::PHYSICAL_BUTTON_LOCKED:
    return "PHYSICAL_BUTTON_LOCKED";
  case LogEvent::ALARM_DISARMED:
    return "ALARM_DISARMED";
  case LogEvent::UNAUTHORIZED_ATTEMPT:
    return "UNAUTHORIZED_ATTEMPT";
  }
  return "UNKNOWN_EVENT";
}

enum class EnrollmentStatus {
  IDLE,
  ENROLLING,
  PLACE_FIRST_FINGER,
  PLACE_SECOND_FINGER,
  RAISE_FINGER,
  SUCCESS,
  FAILED,
  CANCELLED
};

inline const char *enrollmentStatusToString(EnrollmentStatus status) {
  switch (status) {
  case EnrollmentStatus::IDLE:
    return "IDLE";
  case EnrollmentStatus::ENROLLING:
    return "ENROLLING";
  case EnrollmentStatus::PLACE_FIRST_FINGER:
    return "PLACE_FIRST_FINGER";
  case constants::EnrollmentStatus::PLACE_SECOND_FINGER:
    return "PLACE_SECOND_FINGER";
  case EnrollmentStatus::RAISE_FINGER:
    return "RAISE_FINGER";
  case EnrollmentStatus::SUCCESS:
    return "SUCCESS";
  case EnrollmentStatus::FAILED:
    return "FAILED";
  case EnrollmentStatus::CANCELLED:
    return "CANCELLED";
  }
  return "UNKNOWN";
}

constexpr unsigned long ENROLLMENT_RESET_DELAY_MS = 4000;
} // namespace constants
