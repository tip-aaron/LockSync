#pragma once
#include <Arduino.h>

namespace utilities {
// Print memory usage every N loop iterations
void printMemoryUsage(uint32_t iterationInterval = 100);

// Print memory usage at a target time interval (e.g., 1000ms = 1 Hz update
// rate)
void printMemoryUsageTimed(uint32_t intervalMs = 1000);
} // namespace utilities