#pragma once

#include "constants/peripherals.hpp"
#include <Arduino.h>
#include <ESP32Servo.h>

class LockServo {
public:
  LockServo(uint8_t pin = constants::SERVO_PIN,
            int lockedAngle = constants::SERVO_LOCKED_ANGLE,
            int unlockedAngle = constants::SERVO_UNLOCKED_ANGLE);

  void begin(bool initialLockedState = true);
  void lock();
  void unlock();
  void setLocked(bool locked);

  // Non-blocking watcher to auto-detach PWM signal after movement completes
  void tick();

private:
  Servo _servo;
  int _currentAngle = -1;
  uint8_t _pin;
  int _lockedAngle;
  int _unlockedAngle;

  bool _isAttached = false;
  uint32_t _lastMovementTimestamp = 0;

  void attachAndWrite(int targetAngle);
};