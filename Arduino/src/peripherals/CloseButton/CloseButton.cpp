#include "CloseButton.hpp"

CloseButton::CloseButton(uint8_t pin, uint32_t debounceMs, bool activeLow)
    : _pin(pin), _debounceMs(debounceMs), _activeLow(activeLow),
      _lastRawState(activeLow ? HIGH : LOW),
      _stableState(activeLow ? HIGH : LOW), _lastDebounceMs(0) {}

void CloseButton::begin() {
  pinMode(_pin, _activeLow ? INPUT_PULLUP : INPUT_PULLDOWN);

  bool initialRead = digitalRead(_pin);
  _lastRawState = initialRead;
  _stableState = initialRead;
}

bool CloseButton::isTriggered(bool isLocked) {
  bool currentRawState = digitalRead(_pin);
  unsigned long now = millis();

  if (currentRawState != _lastRawState) {
    _lastDebounceMs = now;
    _lastRawState = currentRawState;
  }

  if ((now - _lastDebounceMs) < _debounceMs) {
    return false;
  }

  if (currentRawState == _stableState) {
    return false;
  }

  _stableState = currentRawState;
  bool isPressed = _activeLow ? (_stableState == LOW) : (_stableState == HIGH);

  return isPressed && !isLocked;
}