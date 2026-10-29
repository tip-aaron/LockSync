#include "firebase/FirebaseManager.hpp"
#include "constants/common.hpp"
#include "constants/firebase.hpp"
#include "firebase/services/FirebaseStreamHandler.hpp"
#include "session/FB_Session.h"
#include <set>

FirebaseManager::FirebaseManager() : _streamHandler(&_reqData) {}

void FirebaseManager::begin(LockCommandCallback onLock,
                            EnrollCommandCallback onEnroll,
                            DeleteCommandCallback onDelete,
                            CancelEnrollCallback onCancel,
                            ResetAlarmCallback onResetAlarm) {
  _config.database_url = constants::FIREBASE_HOST;
  _config.api_key = constants::FIREBASE_AUTH;

  Firebase.begin(&_config, &_auth);
  Firebase.reconnectNetwork(true);
  _reqData.setBSSLBufferSize(4096, 1024); // 4KB Rx buffer, 1KB Tx buffer
  _reqData.setResponseSize(constants::FIREBASE_STREAM_BUFFER_SIZE);

  if (Firebase.ready()) {
    Firebase.RTDB.setString(
        &_reqData, constants::DB_PATH_ENROLL_STATUS,
        constants::enrollmentStatusToString(constants::EnrollmentStatus::IDLE));
  }

  _streamHandler.begin(onLock, onEnroll, onDelete, onCancel, onResetAlarm);

  _isInitialized = true;

  Serial.printf(
      "[FIREBASE MANAGER] Orchestrator initialized (Buffer: %.2f KB).\n",
      constants::FIREBASE_STREAM_BUFFER_SIZE / 1024.0f);
}
void FirebaseManager::notifyHardwareAction() {
  _lastHardwareActionMs = millis();
}
void FirebaseManager::tick(
    bool isNetworkAvailable, bool &currentLockState, uint16_t& unauthorizedCount,
    constants::EnrollmentStatus &currentEnrollmentStatus) {
  if (!_isInitialized || !isNetworkAvailable) {
    return;
  }

  // If Wi-Fi is connected, but Firebase isn't authenticated/ready yet, try
  // signing up/connecting
  static bool hasTriedSignup = false;

  if (!Firebase.ready()) {
    if (!hasTriedSignup && Firebase.signUp(&_config, &_auth, "", "")) {
      Serial.println("[FIREBASE] Background anonymous auth signup successful.");

      hasTriedSignup = true; // Stop spamming signup attempts
    }

    return;
  }

  _streamHandler.tick(isNetworkAvailable);
  // Pass enrollment status down to state sync
_stateSync.tick(_reqData, currentLockState, unauthorizedCount,
                  currentEnrollmentStatus, isNetworkAvailable);
  _heartbeat.tick(_reqData, isNetworkAvailable);

  bool inHardwareCooldown = (millis() - _lastHardwareActionMs < 500);

if (!inHardwareCooldown) {
    if (_logger.getQueueCount() > 0) {
      _logger.flushPendingLogs(_reqData, isNetworkAvailable);
    }
    
    if (_lastUsedCount > 0) {
      flushPendingLastUsedUpdates(isNetworkAvailable);
    }
  }
}

bool FirebaseManager::logEvent(const char *eventType, bool isNetworkAvailable) {
  return _logger.logEvent(_reqData, eventType, isNetworkAvailable);
}

void FirebaseManager::syncFingerprints(FingerprintSensor &sensor, Buzzer &buzzer) {
  if (_hasSyncedFingerprints || !Firebase.ready()) return;

  Serial.println("[SYNC] Reconciling hardware vs Firebase fingerprints...");

  std::set<uint16_t> firebaseSlots;

  bool getSuccess = Firebase.RTDB.getJSON(&_reqData, "lockers/locker_01/fingerprints");

  if (getSuccess && _reqData.dataType() != "null" && _reqData.dataType() != "null_string") {
    FirebaseJson &json = _reqData.jsonObject();
    size_t count = json.iteratorBegin();
    FirebaseJson::IteratorValue value;

    for (size_t i = 0; i < count; i++) {
      value = json.valueAt(i);
      if (value.type == FirebaseJson::JSON_OBJECT) {
        int slotId = atoi(value.key.c_str());
        if (slotId > 0) {
          firebaseSlots.insert(static_cast<uint16_t>(slotId));
        }
      }
    }
    json.iteratorEnd();
    Serial.printf("[SYNC] Found %u registered fingerprint slot(s) in Firebase.\n", firebaseSlots.size());
  } else {
    Serial.println("[SYNC] /fingerprints node does not exist in Firebase. Purging all hardware models.");
  }

  uint16_t deletedCount = 0;
  for (uint16_t slot = 1; slot <= 162; slot++) {
    if (sensor.hasModel(slot)) {
      if (firebaseSlots.find(slot) == firebaseSlots.end()) {
        Serial.printf("[SYNC] Slot #%u missing in Firebase. Deleting...\n", slot);
        if (sensor.deleteSlot(slot)) {
          deletedCount++;
        }
      }
    }
  }

  // Play beep ONCE after all orphan deletions finish
  if (deletedCount > 0) {
    buzzer.play(BuzzerSound::DELETED);
  }

  Serial.printf("[SYNC COMPLETE] Purged %u orphan fingerprint(s) from hardware.\n", deletedCount);
  _hasSyncedFingerprints = true;
}


bool FirebaseManager::updateFingerprintLastUsed(uint16_t slotId, bool isNetworkAvailable) {
  time_t now = time(nullptr);
  enqueueLastUsedUpdate(slotId, now);
  return true;
}

void FirebaseManager::enqueueLastUsedUpdate(uint16_t slotId, time_t timestamp) {
  _lastUsedQueue[_lastUsedTail].slotId = slotId;
  _lastUsedQueue[_lastUsedTail].timestamp = timestamp;
  _lastUsedTail = (_lastUsedTail + 1) % MAX_PENDING_LAST_USED;

  if (_lastUsedCount < MAX_PENDING_LAST_USED) {
    _lastUsedCount++;
  } else {
    _lastUsedHead = (_lastUsedHead + 1) % MAX_PENDING_LAST_USED;
    Serial.println("[FIREBASE] Queue full! Dropped oldest lastUsed update.");
  }
}

void FirebaseManager::flushPendingLastUsedUpdates(bool isNetworkAvailable) {
  if (_lastUsedCount > 0 && isNetworkAvailable) {
    PendingLastUsedUpdate &entry = _lastUsedQueue[_lastUsedHead];

    char dbPath[64];
    snprintf(dbPath, sizeof(dbPath), "lockers/locker_01/fingerprints/%u/lastUsed", entry.slotId);

    // Write epoch timestamp (milliseconds if NTP synced, fallback to seconds)
    int64_t timestampMs = (int64_t)entry.timestamp * 1000;

    bool success = Firebase.RTDB.setInt(&_reqData, dbPath, timestampMs);

    if (success) {
      Serial.printf("[FIREBASE FLUSH] Updated lastUsed for fingerprint Slot #%u (%u remaining)\n",
                    entry.slotId, _lastUsedCount - 1);
      _lastUsedHead = (_lastUsedHead + 1) % MAX_PENDING_LAST_USED;
      _lastUsedCount--;
    } else {
      Serial.printf("[FIREBASE FLUSH ERROR] lastUsed update failed: %s\n", _reqData.errorReason().c_str());
    }
  }
}
