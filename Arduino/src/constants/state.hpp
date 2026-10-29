#pragma once

#include "constants/common.hpp"
#include <cstdint>
#include <WString.h>

namespace locker_state {
extern bool isLocked;
extern bool isEnrolling;
extern uint16_t unauthorizedCount;
extern constants::EnrollmentStatus enrollmentStatus;
extern unsigned long enrollmentFinishedTimestamp;
}
