#pragma once

#include <Arduino.h>
#include <constants/peripherals.hpp>

enum class BuzzerSound {
  UNAUTHORIZED,
  SUCCESSFUL_UNLOCK,
  LOCK,
  ENROLLMENT_START,
  PLACE_FINGER_1,
  RELEASE_FINGER,
  PLACE_FINGER_2,
  ENROLL_SUCCESS,
  ENROLL_FAILED,
  ENROLL_CANCELLED,
  DELETED
};

struct BeepStep {
  uint16_t onMs;
  uint16_t offMs;
};
class Buzzer {
public:
  Buzzer(uint8_t pin, uint8_t channel = 0);

  void begin();
  void startTone(uint32_t frequency);
  void stopTone();
  void play(BuzzerSound sound);
  void tick();

private:
  uint8_t _pin;
  uint8_t _channel;
  BuzzerSound _currentSound;
  bool _isPlaying = false;
  
  uint8_t _stepIndex = 0;
  bool _inPause = false;
  unsigned long _stepStartTime = 0;

  void _getPattern(BuzzerSound sound, const BeepStep *&pattern, uint8_t &stepCount);
};