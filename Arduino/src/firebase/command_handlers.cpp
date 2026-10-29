#include "command_handlers.hpp"
#include "constants/common.hpp"
#include "constants/state.hpp"
#include "peripherals/FingerprintSensor/FingerprintSensor.hpp"
#include <Arduino.h>

namespace command_handlers {
static FirebaseManager *_fbManager = nullptr;
static NetworkManager *_netManager = nullptr;
static LockServo *_lockServo = nullptr;
static FingerprintSensor *_fingerSensor = nullptr;
static Buzzer *_buzzer = nullptr;

// Internal non-blocking enrollment tracking variables
static uint16_t _enrollTargetSlot = 0;
static unsigned long _stepStartTime = 0;
static unsigned long _liftStartTime = 0;

static void _failEnrollment(bool isOnline) {
  locker_state::isEnrolling = false;
  locker_state::enrollmentStatus = constants::EnrollmentStatus::FAILED;
  locker_state::enrollmentFinishedTimestamp = millis();

  if (_buzzer) {
    _buzzer->play(BuzzerSound::ENROLL_FAILED);
  }

  if (_fbManager) {
    _fbManager->logEvent(
        constants::logEventToString(
            constants::LogEvent::FINGERPRINT_ENROLLMENT_FAILED),
        isOnline);
  }
}

void init(FirebaseManager &fb, NetworkManager &net, LockServo &servo,
          FingerprintSensor &fingerSensor, Buzzer &buzzer) {
  _fbManager = &fb;
  _netManager = &net;
  _lockServo = &servo;
  _fingerSensor = &fingerSensor;
  _buzzer = &buzzer;
}

void tick() {
  const bool isOnline = _netManager && _netManager->isConnected();

  // ---------------------------------------------------------------------------
  // NON-BLOCKING ENROLLMENT STATE MACHINE
  // ---------------------------------------------------------------------------
  switch (locker_state::enrollmentStatus) {

  case constants::EnrollmentStatus::PLACE_FIRST_FINGER: {
    // 1. Timeout Check
    if (millis() - _stepStartTime > constants::FINGERPRINT_TIMEOUT_MS) {
      Serial.println("[ENROLL] First scan timed out.");
      _failEnrollment(isOnline);
      break;
    }

    // 2. Non-blocking Scan Attempt
    if (_fingerSensor && _fingerSensor->enrollStep1()) {
      Serial.println("[ENROLL] First scan complete. Requesting finger lift.");
      locker_state::enrollmentStatus = constants::EnrollmentStatus::RAISE_FINGER;
      _liftStartTime = millis();

      if (_buzzer) {
        _buzzer->play(BuzzerSound::RELEASE_FINGER);
      }

      _fbManager->logEvent(
          constants::logEventToString(
              constants::LogEvent::FINGERPRINT_FIRST_SCAN_COMPLETE),
          isOnline);
    }
    break;
  }

  case constants::EnrollmentStatus::RAISE_FINGER: {
    // Non-blocking lift pause delay before requesting second scan
    if (millis() - _liftStartTime >= constants::FINGERPRINT_LIFT_DELAY_MS) {
      Serial.println("[ENROLL] Lift delay complete. Prompting second scan.");
      locker_state::enrollmentStatus =
          constants::EnrollmentStatus::PLACE_SECOND_FINGER;
      _stepStartTime = millis(); // Reset step timeout for second scan

      if (_buzzer) {
        _buzzer->play(BuzzerSound::PLACE_FINGER_2);
      }
    }
    break;
  }

  case constants::EnrollmentStatus::PLACE_SECOND_FINGER: {
    // 1. Timeout Check
    if (millis() - _stepStartTime > constants::FINGERPRINT_TIMEOUT_MS) {
      Serial.println("[ENROLL] Second scan timed out.");
      _failEnrollment(isOnline);
      break;
    }

    // 2. Non-blocking Scan Attempt
    if (_fingerSensor && _fingerSensor->enrollStep2()) {
      Serial.println("[ENROLL] Second scan complete. Storing model...");

      _fbManager->logEvent(
          constants::logEventToString(
              constants::LogEvent::FINGERPRINT_SECOND_SCAN_COMPLETE),
          isOnline);

      if (_fingerSensor->storeModel(_enrollTargetSlot)) {
        Serial.printf("[ENROLL SUCCESS] Fingerprint stored in Slot #%u\n",
                      _enrollTargetSlot);

        locker_state::enrollmentStatus = constants::EnrollmentStatus::SUCCESS;
        locker_state::isEnrolling = false;
        locker_state::enrollmentFinishedTimestamp = millis();

        if (_buzzer) {
          _buzzer->play(BuzzerSound::ENROLL_SUCCESS);
        }

        _fbManager->logEvent(
            constants::logEventToString(
                constants::LogEvent::FINGERPRINT_ENROLLED),
            isOnline);
      } else {
        Serial.println("[ENROLL ERROR] Failed to store template model.");
        _failEnrollment(isOnline);
      }
    }
    break;
  }

  case constants::EnrollmentStatus::SUCCESS:
  case constants::EnrollmentStatus::FAILED:
  case constants::EnrollmentStatus::CANCELLED: {
    // Terminal State Reconciler: Reverts back to IDLE after display delay
    if (locker_state::enrollmentFinishedTimestamp > 0 &&
        millis() - locker_state::enrollmentFinishedTimestamp >
            constants::ENROLLMENT_RESET_DELAY_MS) {

      Serial.println("[SYSTEM] Reconciling enrollment state back to IDLE.");
      locker_state::enrollmentStatus = constants::EnrollmentStatus::IDLE;
      locker_state::enrollmentFinishedTimestamp = 0;
    }
    break;
  }

  default:
    break;
  }
}

void handleLockCommand(bool shouldLock) {
  if (!_fbManager || !_netManager) {
    return;
  }

  if (locker_state::isLocked != shouldLock) {
    locker_state::isLocked = shouldLock;

    if (!shouldLock) {
      locker_state::unauthorizedCount = 0;
    }

    Serial.printf("[SYSTEM] Remote command executed. Locker state: %s\n",
                  shouldLock ? "LOCKED" : "UNLOCKED");

    const bool isOnline = _netManager->isConnected();

    _lockServo->setLocked(shouldLock);

    if (_buzzer) {
      if (shouldLock) {
        _buzzer->play(BuzzerSound::LOCK);
      } else {
        _buzzer->play(BuzzerSound::SUCCESSFUL_UNLOCK);
      }
    }

    _fbManager->notifyHardwareAction();

    auto event = shouldLock ? constants::LogEvent::REMOTE_LOCKED
                            : constants::LogEvent::REMOTE_UNLOCKED;

    _fbManager->logEvent(constants::logEventToString(event), isOnline);
  }
}

void handleResetUnauthorizedCommand() {
  if (!_fbManager || !_netManager) {
    return;
  }

  const bool isOnline = _netManager->isConnected();

  Serial.println("[SYSTEM] Remote disarm command received. Resetting unauthorized attempts.");

  locker_state::unauthorizedCount = 0;

  _fbManager->logEvent(
      constants::logEventToString(constants::LogEvent::ALARM_DISARMED),
      isOnline);
}

void handleEnrollCommand(uint16_t slotId) {
  if (!_fbManager || !_netManager || !_fingerSensor) {
    return;
  }

  const bool isOnline = _netManager->isConnected();

  Serial.printf("[SYSTEM] Enrollment command received for Slot ID: %u\n", slotId);

  _enrollTargetSlot = slotId;
  _stepStartTime = millis();

  locker_state::isEnrolling = true;
  locker_state::enrollmentStatus = constants::EnrollmentStatus::PLACE_FIRST_FINGER;

  if (_buzzer) {
    _buzzer->play(BuzzerSound::ENROLLMENT_START);
    _buzzer->play(BuzzerSound::PLACE_FINGER_1);
  }

  _fbManager->logEvent(
      constants::logEventToString(
          constants::LogEvent::FINGERPRINT_ENROLLMENT_STARTED),
      isOnline);
}

void handleDeleteCommand(int16_t slotId) {
  if (!_fbManager || !_netManager) {
    return;
  }

  const bool isOnline =
      _netManager->isConnected() && _netManager->isTimeSynced();

  if (slotId == -1) {
    Serial.println("[SYSTEM] Request to purge ALL stored fingerprints.");

    if (_fingerSensor->deleteSlot(-1)) {
      if (_buzzer) {
        _buzzer->play(BuzzerSound::DELETED);
      }

      _fbManager->logEvent(
          constants::logEventToString(
              constants::LogEvent::ALL_FINGERPRINTS_DELETED),
          isOnline);
    } else {
      if (_buzzer) {
        _buzzer->play(BuzzerSound::ENROLL_FAILED);
      }
    }
  } else {
    Serial.printf("[SYSTEM] Request to delete fingerprint Slot ID: %d\n", slotId);

    if (_fingerSensor->deleteSlot(slotId)) {
      if (_buzzer) {
        _buzzer->play(BuzzerSound::DELETED);
      }

      char logBuf[constants::MAX_LOG_EVENT_LEN];
      snprintf(logBuf, sizeof(logBuf), "FP_DELETED_SLOT_%d", slotId);

      _fbManager->logEvent(logBuf, isOnline);
    } else {
      if (_buzzer) {
        _buzzer->play(BuzzerSound::ENROLL_FAILED);
      }
    }
  }
}

void handleCancelEnrollCommand() {
  if (!_fbManager || !_netManager || !locker_state::isEnrolling) {
    return;
  }

  const bool isOnline = _netManager->isConnected();

  Serial.println("[SYSTEM] Enrollment cancellation requested.");

  locker_state::isEnrolling = false;
  locker_state::enrollmentStatus = constants::EnrollmentStatus::CANCELLED;
  locker_state::enrollmentFinishedTimestamp = millis();

  if (_buzzer) {
    _buzzer->play(BuzzerSound::ENROLL_CANCELLED);
  }

  _fbManager->logEvent(
      constants::logEventToString(
          constants::LogEvent::FINGERPRINT_ENROLLMENT_CANCELLED),
      isOnline);
}
} // namespace command_handlers