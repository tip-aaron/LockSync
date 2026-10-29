#pragma once

#include <cstdint>

namespace constants {

// Physical Lock Button GPIO pin
constexpr uint8_t BUTTON_PIN = 27;
// Time-based debounce window (Milliseconds)
// Tactile micro-switches suffer from mechanical contact bounce, causing rapid
// electrical oscillations for 5 ms to 20 ms upon press/release. A 50 ms
// debounce threshold completely filters out mechanical noise while remaining
// far below human tactile perception (~100 ms), ensuring instantaneous response
// without double-trigger glitches.
constexpr uint32_t BUTTON_DEBOUNCE_MS = 50;
// Active-LOW logic configuration (uses ESP32 internal INPUT_PULLUP resistor)
// 1. Eliminates extra hardware: Utilizes the ESP32 internal ~45 kΩ pull-up
// resistor to 3.3V,
//    removing the need for external physical pull-down resistors.
// 2. Prevents floating states: Unpressed state is held cleanly HIGH (3.3V);
// pressing the button
//    connects the pin directly to GND (0V / LOW).
// 3. Hardware safety: Routing GND to external enclosure buttons prevents
// potential short-circuit
//    damage if a wire chafes against metal frames, unlike active-HIGH 3.3V
//    lines.
constexpr bool BUTTON_ACTIVE_LOW = true;

constexpr uint8_t SERVO_PIN = 18;
// ESP32 Hardware Timer Index (0 to 3)
// ESP32 features 4 hardware timers for LEDC PWM generation. Explicitly
// reserving Timer 0 prevents background resource contention and race conditions
// caused by third-party libraries (e.g., tone generation, soft timers)
// dynamically claiming hardware timers.
constexpr uint8_t SERVO_TIMER_NUM = 0;
// PWM Frequency (Hertz)
// Standard RC micro-servos (SG90) expect a 50 Hz pulse refresh rate, resulting
// in a 20 ms frame period (1 / 50 Hz = 0.020 s). The servo's internal control
// IC decodes shaft position strictly from the HIGH pulse duration within this
// 20 ms window.
constexpr uint32_t SERVO_PWM_FREQ_HZ = 50;
constexpr int SERVO_LOCKED_ANGLE = 0;  // Deadbolt engaged position
constexpr int SERVO_UNLOCKED_ANGLE = 90; // Deadbolt retracted position
// SG90 Pulse Width Limits (Microseconds)
// 544 us  = 2.72% duty cycle of 20ms (50Hz) frame period -> 0 degrees shaft
// position 2400 us = 12.00% duty cycle of 20ms (50Hz) frame period -> 180
// degrees shaft position
constexpr uint16_t SERVO_MIN_PULSE_US = 544;
constexpr uint16_t SERVO_MAX_PULSE_US = 2400;
// Auto-Detach Delay (Milliseconds)
// Derived from SG90 datasheet speed rating at 4.8V (0.12s per 60 deg = 2.0
// ms/deg):
// 1. Nominal 90 deg sweep time: 90 deg * 2.0 ms/deg = 180 ms
// 2. Mechanical load margin (1.5x): 180 ms * 1.5 = 270 ms
// 3. Voltage sag margin (1.5x): 270 ms * 1.5 = 405 ms
// 4. Gear dampening & settling time: 405 ms + 195 ms = 600 ms
constexpr uint32_t SERVO_DETACH_DELAY_MS = 600;

// Hardware UART Pins (ESP32 Serial2 default or custom remapping)
constexpr uint8_t FINGERPRINT_RX_PIN =
    16; // Connects to AS608 TX (White wire typically)
constexpr uint8_t FINGERPRINT_TX_PIN =
    17; // Connects to AS608 RX (Green wire typically)
// Baud Rate: 57600
// WHY: This is the default factory baud rate for the AS608 / Adafruit optical
// sensor module. While it can be changed via software commands, 57600 provides
// a rock-solid, reliable communication speed over standard jumper wires without
// bit-error drift.
constexpr uint32_t FINGERPRINT_BAUD_RATE = 57600;
// Timeout: 10,000 ms (10 seconds)
// WHY: Gives the user ample time to press their finger onto the sensor reader
// after initiating an enrollment or verification command through the app,
// without locking up the system indefinitely if they walk away.
constexpr uint32_t FINGERPRINT_TIMEOUT_MS = 10000;
// Poll Interval: 100 ms
// WHY: When waiting for a finger press, continuously calling `getImage()` every
// single CPU cycle would flood the serial buffer, spike CPU usage to 100%, and
// trigger the ESP32 Task Watchdog Timer (WDT). A 100ms yield allows the RTOS
// and background network routines (`fbManager.tick()`) breathing room.
constexpr uint32_t FINGERPRINT_POLL_INTERVAL_MS = 100;
// Lift Delay: 2,000 ms (2 seconds)
// WHY: During enrollment, the AS608 requires a two-step capture using the
// *same* finger. This delay forces a brief pause after the first scan
// completes, giving the user sufficient physical time to lift their finger off
// the optical glass before placing it down again for the second capture.
constexpr uint32_t FINGERPRINT_LIFT_DELAY_MS = 2000;

constexpr uint8_t BUZZER_PIN = 25; // Example GPIO pin for active/passive buzzer
constexpr uint8_t BUZZER_CHANNEL = 1; // LEDC channel (0 is used by servo)
// Base PWM Frequency: 2000 Hz (2 kHz)
// WHY: The human ear is biologically most sensitive to frequencies between
// 2,000 Hz and 4,000 Hz due to the acoustic amplification of the human ear
// canal. A 2 kHz base carrier tone cuts cleanly through ambient room noise
// without sounding shrill, harsh, or distorted on cheap electromagnetic/piezo
// buzzers.
constexpr uint32_t BUZZER_PWM_FREQ_HZ = 2000;
// PWM Duty Resolution: 8 bits (0 to 255 scale)
// WHY:
// 1. Hardware Compatibility: An 8-bit resolution sets the maximum duty cycle
// range to 256 steps ($2^8$),
//    making a 50% volume balance trivial to compute (`255 / 2 = 127`).
// 2. Timer Clock Safety: The ESP32 LEDC hardware timer requires a trade-off
// between frequency and bit depth.
//    At a low 8-bit depth, the PWM peripheral operates with zero clock
//    constraint overhead on the 80 MHz APB clock, guaranteeing rock-solid tone
//    pitch precision when changing frequencies dynamically on the fly.
constexpr uint8_t BUZZER_RESOLUTION_BITS = 8;
constexpr uint32_t TONE_NONE = 0;

} // namespace constants
