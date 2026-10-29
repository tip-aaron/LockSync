#pragma once
#include <Arduino.h>
#include <esp32-hal-gpio.h>
#include <esp32-hal.h>

class CloseButton {
public:
    // Constructor with configurable pin, debounce time, and logic polarity (default: active LOW with PULLUP)
    CloseButton(uint8_t pin, uint32_t debounceMs, bool activeLow);

    // Configures hardware GPIO mode
    void begin();

    // Call inside main loop(). Returns true on a debounced button press if the lock is currently open.
    bool isTriggered(bool isLocked);

private:
    uint8_t _pin;
    uint32_t _debounceMs;
    bool _activeLow;

    bool _lastRawState;
    bool _stableState;
    unsigned long _lastDebounceMs;
};