#include "state.hpp"

namespace locker_state {
bool isLocked = false;
bool isEnrolling = false;
uint16_t unauthorizedCount = 0;
constants::EnrollmentStatus enrollmentStatus = constants::EnrollmentStatus::IDLE;
unsigned long enrollmentFinishedTimestamp = 0;
}