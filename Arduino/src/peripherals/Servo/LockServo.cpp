#include "LockServo.hpp"

LockServo::LockServo(uint8_t pin, int lockedAngle, int unlockedAngle)
    : _pin(pin), _lockedAngle(lockedAngle), _unlockedAngle(unlockedAngle) {}

void LockServo::begin(bool initialLockedState) {
  ESP32PWM::allocateTimer(constants::SERVO_TIMER_NUM);
  _servo.setPeriodHertz(constants::SERVO_PWM_FREQ_HZ);

  setLocked(initialLockedState);
}

void LockServo::lock() {
  Serial.println("[SERVO] Actuating to LOCKED position.");
  attachAndWrite(_lockedAngle);
}

void LockServo::unlock() {
  Serial.println("[SERVO] Actuating to UNLOCKED position.");
  attachAndWrite(_unlockedAngle);
}

void LockServo::setLocked(bool locked) {
  if (locked) {
    lock();
  } else {
    unlock();
  }
}

void LockServo::attachAndWrite(int targetAngle) {
  // 1. Attach pin if currently detached
  if (!_isAttached) {
    _servo.attach(_pin);
    _isAttached = true;
  }

  // 2. Write target angle once pin channel is active
  _servo.write(targetAngle);
  _currentAngle = targetAngle;
  _lastMovementTimestamp = millis();
}

void LockServo::tick() {
  // Detach PWM signal after movement duration to save power & eliminate idle jitter
  if (_isAttached &&
      (millis() - _lastMovementTimestamp >= constants::SERVO_DETACH_DELAY_MS)) {

    _servo.detach();
    _isAttached = false;

    Serial.println("[SERVO] PWM signal detached (Power save / zero jitter).");
  }
}