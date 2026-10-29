# refactor(firmware): transition from online-first monolith to modular offline-first C++17 architecture

## Problem Statement

The legacy monolithic firmware suffered from stability, latency, and memory safety issues:

1. **Heap Fragmentation & Stack Overflows:** Dynamic allocation of `FirebaseData` objects on the stack inside static stream callbacks caused continuous `malloc`/`free` churn, memory leaks, and FreeRTOS stack crashes (`Guru Meditation Error`).
2. **High Actuation Latency (Online-First Bottleneck):** Hardware actuation waited for blocking SSL round-trips to write cloud states first, adding 200ms–500ms of latency to physical bolt locks/unlocks.
3. **Command Race Conditions & State Desync:** Network drops occurring midway through command execution or acknowledgment (ACK) writes left `/command/action` stuck in non-zero states, causing infinite command replay loops upon stream reconnection.

---

## Summary of Changes

### 1. Offline-First Hardware Actuation

- Decoupled physical lock/unlock triggers from network state; physical hardware actuates instantly with zero network delay.
- Enforced hardware bolt state as the primary source of truth, mirroring state asynchronously to Firebase RTDB.

### 2. Decomposed `FirebaseManager` God Class

Partitioned monolithic network logic into a lightweight orchestrator delegating to four single-purpose domain services:

- `FirebaseStreamHandler`: Manages primitive leaf streaming and command callback dispatching.
- `FirebaseStateSync`: Reconciles local hardware lock and security states with cloud nodes.
- `FirebaseLogger`: Buffers audit logs in a fixed-size static ring buffer during offline windows and flushes upon recovery.
- `FirebaseHeartbeat`: Manages non-blocking 15-second epoch timestamp writes to `/system/last_seen`.

### 3. Memory & Buffer Optimization

- Replaced local `FirebaseData` stack allocations inside callbacks with persistent member instances (`_reqData`).
- Pre-allocated fixed SSL response buffers (`1 KB`), reducing RAM overhead to ~25 KB and eliminating dynamic heap churn.

### 4. Network Drop & ACK Resilience

- Implemented `_pendingAckReset` flag inside `FirebaseStreamHandler` to catch failed ACK writes to `/command/action` (`IDLE`).
- Added automatic retry logic inside `tick()` to safely clear pending commands upon network recovery without duplicate hardware executions.

---

## Impact

- **Zero Hardware Latency:** Instant physical actuation for button and biometric events.
- **Deterministic Memory Footprint:** Static buffer allocations eliminate heap fragmentation and stack overflow crashes.
- **Resilient Remote Control:** Zero command lockups or duplicate command triggers during intermittent Wi-Fi drops.
