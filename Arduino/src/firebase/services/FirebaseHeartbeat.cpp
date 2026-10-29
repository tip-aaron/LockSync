#include "FirebaseHeartbeat.hpp"
#include <time.h>

void FirebaseHeartbeat::tick(FirebaseData &reqData, bool isNetworkAvailable) {
  if (!Firebase.ready()) {
    return;
  }
  
  if (isNetworkAvailable && (millis() - _lastHeartbeatTimestamp >=
                             constants::HEARTBEAT_INTERVAL_MS)) {
    sendHeartbeat(reqData, isNetworkAvailable);
  }
}

bool FirebaseHeartbeat::sendHeartbeat(FirebaseData &reqData,
                                      bool isNetworkAvailable) {
  if (!isNetworkAvailable) {
    return false;
  }

  time_t now = time(nullptr);
  bool success = Firebase.RTDB.setInt(&reqData, constants::DB_PATH_HEARTBEAT,
                                      static_cast<int>(now));

  if (success) {
    _lastHeartbeatTimestamp = millis();

    Serial.printf("[HEARTBEAT] Ping sent successfully. Timestamp: %ld\n", now);
  } else {
    Serial.printf("[HEARTBEAT ERROR] Ping failed: %s\n",
                  reqData.errorReason().c_str());
  }

  return success;
}