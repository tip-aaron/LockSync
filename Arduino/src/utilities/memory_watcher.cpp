#include "memory_watcher.hpp"

namespace {
    constexpr float BYTES_PER_KB = 1024.0f;

    // Helper to format and print memory stats without code duplication
    void logMemoryStats() {
        const float totalHeapKB = ESP.getHeapSize() / BYTES_PER_KB;
        const float freeHeapKB  = ESP.getFreeHeap() / BYTES_PER_KB;
        const float maxBlockKB  = ESP.getMaxAllocHeap() / BYTES_PER_KB;

        Serial.printf(
            "[MEM] Total Heap: %.2f KB | Total Free: %.2f KB | Max Single Block: %.2f KB\n",
            totalHeapKB,
            freeHeapKB,
            maxBlockKB
        );
    }
}

void utilities::printMemoryUsage(uint32_t iterationInterval) {
    static uint32_t iterationCount = 0;
    iterationCount++;

    if (iterationCount >= iterationInterval) {
        iterationCount = 0;
        logMemoryStats();
    }
}

void utilities::printMemoryUsageTimed(uint32_t intervalMs) {
    static unsigned long lastPrintMs = 0;
    const unsigned long currentMs = millis();

    if (currentMs - lastPrintMs >= intervalMs) {
        lastPrintMs = currentMs;
        logMemoryStats();
    }
}