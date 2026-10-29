#include "Buzzer.hpp"
#include <constants/peripherals.hpp>

// -----------------------------------------------------------------------------
// RICH FULL-TONE SOUND PATTERNS (ON ms, OFF ms)
// -----------------------------------------------------------------------------
// "ting... TIIING!" Melodic success chime (70ms lead, 60ms pause, 130ms accent)
static const BeepStep PATTERN_SUCCESS[] = {
    {70, 60}, 
    {130, 0}
};

// "ting!" Solid 70ms lock tone
static const BeepStep PATTERN_LOCK[] = {
    {70, 0}
};

// "ting - ting - TING!" Substantial triple warning sequence
static const BeepStep PATTERN_FAILED[] = {
    {80, 50}, 
    {80, 50}, 
    {140, 0}
};

// "ting-ting" Distinct double prompt
static const BeepStep PATTERN_PROMPT[] = {
    {45, 35}, 
    {45, 0}
};

// "tick" Audible 25ms tick
static const BeepStep PATTERN_SHORT_TICK[] = {
    {25, 0}
};

// "ting... TING!" Clear double deletion chime
static const BeepStep PATTERN_DELETED[] = {
    {60, 40}, 
    {90, 0}
};

Buzzer::Buzzer(uint8_t pin, uint8_t channel) : _pin(pin), _channel(channel) {}

void Buzzer::begin() {
  pinMode(_pin, OUTPUT);
  digitalWrite(_pin, LOW);

  // Spawn a dedicated background task on Core 1 running every 1ms
  xTaskCreatePinnedToCore(
      [](void *pvParameters) {
        Buzzer *instance = static_cast<Buzzer *>(pvParameters);
        for (;;) {
          instance->tick();
          vTaskDelay(pdMS_TO_TICKS(1));
        }
      },
      "BuzzerTask",
      2048,
      this,
      1,
      nullptr,
      1
  );
}

void Buzzer::startTone(uint32_t frequency) {
  digitalWrite(_pin, frequency != constants::TONE_NONE ? HIGH : LOW);
}

void Buzzer::stopTone() {
  digitalWrite(_pin, LOW);
  _isPlaying = false;
}

void Buzzer::_getPattern(BuzzerSound sound, const BeepStep *&pattern, uint8_t &stepCount) {
  switch (sound) {
  case BuzzerSound::SUCCESSFUL_UNLOCK:
  case BuzzerSound::ENROLL_SUCCESS:
    pattern = PATTERN_SUCCESS;
    stepCount = sizeof(PATTERN_SUCCESS) / sizeof(BeepStep);
    break;

  case BuzzerSound::LOCK:
    pattern = PATTERN_LOCK;
    stepCount = sizeof(PATTERN_LOCK) / sizeof(BeepStep);
    break;

  case BuzzerSound::UNAUTHORIZED:
  case BuzzerSound::ENROLL_FAILED:
  case BuzzerSound::ENROLL_CANCELLED:
    pattern = PATTERN_FAILED;
    stepCount = sizeof(PATTERN_FAILED) / sizeof(BeepStep);
    break;

  case BuzzerSound::ENROLLMENT_START:
  case BuzzerSound::DELETED:
    pattern = PATTERN_DELETED;
    stepCount = sizeof(PATTERN_DELETED) / sizeof(BeepStep);
    break;

  case BuzzerSound::PLACE_FINGER_1:
  case BuzzerSound::PLACE_FINGER_2:
    pattern = PATTERN_PROMPT;
    stepCount = sizeof(PATTERN_PROMPT) / sizeof(BeepStep);
    break;

  case BuzzerSound::RELEASE_FINGER:
  default:
    pattern = PATTERN_SHORT_TICK;
    stepCount = sizeof(PATTERN_SHORT_TICK) / sizeof(BeepStep);
    break;
  }
}

void Buzzer::play(BuzzerSound sound) {
  _currentSound = sound;
  _stepIndex = 0;
  _inPause = false;
  _stepStartTime = millis();
  _isPlaying = true;

  digitalWrite(_pin, HIGH);
}

void Buzzer::tick() {
  if (!_isPlaying) {
    return;
  }

  const BeepStep *pattern = nullptr;
  uint8_t stepCount = 0;
  _getPattern(_currentSound, pattern, stepCount);

  if (_stepIndex >= stepCount) {
    digitalWrite(_pin, LOW);
    _isPlaying = false;
    return;
  }

  unsigned long now = millis();
  unsigned long elapsed = now - _stepStartTime;
  const BeepStep &currentStep = pattern[_stepIndex];

  if (!_inPause) {
    if (elapsed >= currentStep.onMs) {
      digitalWrite(_pin, LOW);

      if (currentStep.offMs > 0) {
        _inPause = true;
        _stepStartTime = now;
      } else {
        _stepIndex++;
        if (_stepIndex < stepCount) {
          digitalWrite(_pin, HIGH);
          _stepStartTime = now;
        } else {
          _isPlaying = false;
        }
      }
    }
  } else {
    if (elapsed >= currentStep.offMs) {
      _inPause = false;
      _stepIndex++;

      if (_stepIndex < stepCount) {
        digitalWrite(_pin, HIGH);
        _stepStartTime = now;
      } else {
        _isPlaying = false;
      }
    }
  }
}