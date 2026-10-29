#include "firebase/services/FirebaseLogger.hpp"
#include <time.h>

bool FirebaseLogger::logEvent(FirebaseData &reqData, const char *eventType, bool isNetworkAvailable) {
    time_t now = time(nullptr);
    // Instantly enqueue so command handlers never block
    enqueueLog(eventType, now);
    return true;
}
void FirebaseLogger::enqueueLog(const char *eventType, time_t timestamp) {
    strncpy(_logQueue[_queueTail].eventType, eventType, constants::MAX_LOG_EVENT_LEN - 1);
    _logQueue[_queueTail].eventType[constants::MAX_LOG_EVENT_LEN - 1] = '\0';
    _logQueue[_queueTail].timestamp = timestamp;
    _queueTail = (_queueTail + 1) % constants::MAX_PENDING_LOGS;

    if (_queueCount < constants::MAX_PENDING_LOGS) {
        _queueCount++;
    } else {
        _queueHead = (_queueHead + 1) % constants::MAX_PENDING_LOGS;
        Serial.println("[LOGGER] Queue full! Dropped oldest offline log.");
    }
}

void FirebaseLogger::flushPendingLogs(FirebaseData &reqData, bool isNetworkAvailable) {
    // Flush ONLY ONE log per tick to protect main loop timing
    if (_queueCount > 0 && isNetworkAvailable) {
        PendingLog &entry = _logQueue[_queueHead];

        FirebaseJson json;
        json.add("event", entry.eventType);
        json.add("timestamp", entry.timestamp);

        bool success = Firebase.RTDB.pushJSON(&reqData, constants::DB_PATH_SYSTEM_LOGS, &json);

        if (success) {
            Serial.printf("[LOGGER FLUSH] Flushed log '%s' (%u remaining)\n", entry.eventType, _queueCount - 1);
            _queueHead = (_queueHead + 1) % constants::MAX_PENDING_LOGS;
            _queueCount--;
        } else {
            Serial.printf("[LOGGER FLUSH ERROR] Flush interrupted: %s\n", reqData.errorReason().c_str());
        }
    }
}