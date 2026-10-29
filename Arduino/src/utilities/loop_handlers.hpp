#pragma once
#include "firebase/FirebaseManager.hpp"
#include "peripherals/CloseButton/CloseButton.hpp"
#include "peripherals/FingerprintSensor/FingerprintSensor.hpp"
#include "peripherals/Servo/LockServo.hpp"
#include "peripherals/Buzzer/Buzzer.hpp"
#include "utilities/NetworkManager.hpp"
#include <Arduino.h>

namespace loop_handlers {
void init(CloseButton &button, LockServo &servo, FingerprintSensor &finger, 
            NetworkManager &net, FirebaseManager &fb, Buzzer &buzzer);
void processHardwareInputs();
} // namespace loop_handlers