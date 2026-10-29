# ESP32 Smart Locker Firmware

An offline-first, modular C++17 firmware for ESP32 smart lockers. Built for zero-latency local physical actuation, primitive leaf-node cloud streaming via Firebase RTDB, and strict hardware state mirroring.

---

## Key Architectural Features

* **Offline-First Priority:** Physical lock and unlock inputs actuate hardware instantly with zero network dependency.
* **Hardware State Mirroring:** Firebase reflects confirmed physical bolt states instead of optimistic UI estimates.
* **Primitive Leaf Streaming:** Listens to single-integer action codes to maintain a minimal SSL memory footprint (~25 KB RAM) with strict 1 KB buffer limits.
* **Compile-Time Motion Math:** constexpr calculations resolve PWM microsecond pulse bounds (544us to 2400us) and motion timings at compile time.
* **Non-Blocking Auto-Detach:** Detaches PWM signals 600 ms post-actuation to stop motor chatter, coil overheating, and power waste.

---

## System Flow & State Mirroring

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant App as Flutter App
    participant FB as Firebase RTDB
    participant ESP as ESP32 Firmware
    participant HW as Lock Servo

    Note over User, HW: Remote Cloud Command Flow
    User->>App: Tap Unlock Button
    App->>FB: Set Action UNLOCK
    FB-->>ESP: Stream Callback UNLOCK
    ESP->>HW: Actuate SG90 Servo
    ESP->>ESP: Set Lock State FALSE
    ESP->>FB: Write Status Unlocked
    ESP->>FB: Reset Action IDLE
    FB-->>App: Stream Update Unlocked
    App->>User: UI Updates to Unlocked

    Note over User, HW: Local Physical Button Flow
    User->>HW: Press Physical Close Button
    HW->>ESP: Debounced Trigger Signal
    ESP->>HW: Actuate SG90 Servo
    ESP->>ESP: Set Lock State TRUE
    ESP->>FB: Write Status Locked
    FB-->>App: Stream Update Locked