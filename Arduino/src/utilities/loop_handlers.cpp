#include "loop_handlers.hpp"
#include "constants/common.hpp"
#include "constants/state.hpp"

namespace loop_handlers {
static CloseButton *_closeButton = nullptr;
static LockServo *_lockServo = nullptr;
static FingerprintSensor *_fingerSensor = nullptr;
static NetworkManager *_netManager = nullptr;
static FirebaseManager *_fbManager = nullptr;
static Buzzer *_buzzer = nullptr;

constexpr unsigned long UNAUTHORIZED_COOLDOWN_MS = 2000;
constexpr unsigned long ALARM_REPEAT_INTERVAL_MS =
    1000; // Continuous alarm interval
constexpr uint8_t ALARM_TRIGGER_THRESHOLD =
    3; // Trigger persistent alarm after 3 attempts

static unsigned long lastUnauthorizedLogTime = 0;
static unsigned long lastAlarmToneTime = 0;

void init(CloseButton &button, LockServo &servo, FingerprintSensor &finger,
          NetworkManager &net, FirebaseManager &fb, Buzzer &buzzer) {
  _closeButton = &button;
  _lockServo = &servo;
  _fingerSensor = &finger;
  _netManager = &net;
  _fbManager = &fb;
  _buzzer = &buzzer;
}

static void handleCloseButton(bool isOnline) {
  if (_closeButton && _closeButton->isTriggered(locker_state::isLocked)) {
    locker_state::isLocked = true;
    Serial.println("[HARDWARE] Physical Close Button Pressed!");

    _lockServo->lock();

    if (_buzzer) {
      _buzzer->play(BuzzerSound::LOCK);
    }

    _fbManager->logEvent("PHYSICAL_BUTTON_LOCKED", isOnline);
  }
}

static void handleSuccessfulMatch(uint16_t matchedId, bool isOnline) {
  if (locker_state::isLocked) {
    locker_state::unauthorizedCount = 0; // Clears alarm state on valid entry
    locker_state::isLocked = false;

    _lockServo->unlock();

    if (_buzzer) {
      _buzzer->play(BuzzerSound::SUCCESSFUL_UNLOCK);
    }

    Serial.printf("[HARDWARE] Fingerprint matched Slot #%u. Unlocking.\n",
                  matchedId);

    _fbManager->logEvent(constants::logEventToString(constants::LogEvent::FINGERPRINT_UNLOCKED), isOnline);

    _fbManager->updateFingerprintLastUsed(matchedId, isOnline);
  }
}

static void handleUnauthorizedAttempt(bool isOnline) {
  unsigned long currentMillis = millis();

  if (currentMillis - lastUnauthorizedLogTime > UNAUTHORIZED_COOLDOWN_MS) {
    lastUnauthorizedLogTime = currentMillis;
    locker_state::unauthorizedCount++;

    if (_buzzer && locker_state::unauthorizedCount < ALARM_TRIGGER_THRESHOLD) {
      _buzzer->play(BuzzerSound::UNAUTHORIZED);
    }

    Serial.printf(
        "[SECURITY] Unauthorized fingerprint attempt detected! Total: %u\n",
        locker_state::unauthorizedCount);

    _fbManager->logEvent(
        constants::logEventToString(constants::LogEvent::UNAUTHORIZED_ATTEMPT),
        isOnline);
  }
}

static void handlePersistentSecurityAlarm() {
  // Repeatedly plays security alarm if attempts reach or exceed the threshold
  if (locker_state::unauthorizedCount >= ALARM_TRIGGER_THRESHOLD) {
    unsigned long currentMillis = millis();

    if (currentMillis - lastAlarmToneTime >= ALARM_REPEAT_INTERVAL_MS) {
      lastAlarmToneTime = currentMillis;
      if (_buzzer) {
        _buzzer->play(BuzzerSound::UNAUTHORIZED);
      }
    }
  }
}

static void handleFingerprintScanner(bool isOnline) {
  if (locker_state::isEnrolling || !_fingerSensor) {
    return;
  }

  uint16_t matchedId = 0;
  FingerScanResult scanResult = _fingerSensor->classifyScan(matchedId);

  switch (scanResult) {
  case FingerScanResult::MATCHED:
    handleSuccessfulMatch(matchedId, isOnline);
    break;
  case FingerScanResult::UNAUTHORIZED:
    handleUnauthorizedAttempt(isOnline);
    break;
  case FingerScanResult::NO_FINGER:
  case FingerScanResult::ERROR:
  default:
    break;
  }
}

void processHardwareInputs() {
  if (!_netManager) {
    return;
  }

  const bool isOnline = _netManager->isConnected();

  handleCloseButton(isOnline);
  handleFingerprintScanner(isOnline);
  handlePersistentSecurityAlarm();
}

} // namespace loop_handlers
