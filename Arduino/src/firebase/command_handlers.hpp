#pragma once

#include "firebase/FirebaseManager.hpp"
#include "peripherals/Buzzer/Buzzer.hpp"
#include "peripherals/FingerprintSensor/FingerprintSensor.hpp"
#include "peripherals/Servo/LockServo.hpp"
#include "utilities/NetworkManager.hpp"
#include <cstdint>

namespace command_handlers {
void init(FirebaseManager &fb, NetworkManager &net, LockServo &servo,
          FingerprintSensor &fingerSensor, Buzzer &buzzer);
void tick();
// Stream Callbacks
void handleLockCommand(bool shouldLock);
void handleResetUnauthorizedCommand();
void handleEnrollCommand(uint16_t slotId);
void handleDeleteCommand(int16_t slotId);
void handleCancelEnrollCommand();

} // namespace command_handlers