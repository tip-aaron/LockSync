#pragma once

#include "peripherals/Buzzer/Buzzer.hpp"
#include "peripherals/FingerprintSensor/FingerprintSensor.hpp"
#include "services/FirebaseHeartbeat.hpp"
#include "services/FirebaseLogger.hpp"
#include "services/FirebaseStateSync.hpp"
#include "services/FirebaseStreamHandler.hpp"
#include <Arduino.h>
#include <Firebase_ESP_Client.h>
#include <constants/firebase.hpp>
struct PendingLastUsedUpdate {
  uint16_t slotId;
  time_t timestamp;
};
class FirebaseManager {
public:
  using LockCommandCallback = FirebaseStreamHandler::LockCommandCallback;
  using EnrollCommandCallback = FirebaseStreamHandler::EnrollCommandCallback;
  using DeleteCommandCallback = FirebaseStreamHandler::DeleteCommandCallback;
  using CancelEnrollCallback = FirebaseStreamHandler::CancelEnrollCallback;
  using ResetAlarmCallback = FirebaseStreamHandler::ResetAlarmCallback;
  void syncFingerprints(FingerprintSensor &sensor, Buzzer &buzzer);
  void begin(LockCommandCallback onLock, EnrollCommandCallback onEnroll,
             DeleteCommandCallback onDelete, CancelEnrollCallback onCancel,
             ResetAlarmCallback onResetAlarm);
  bool updateFingerprintLastUsed(uint16_t slotId, bool isNetworkAvailable);
  void tick(bool isNetworkAvailable, bool &currentLockState,
            uint16_t &unauthorizedCount,
            constants::EnrollmentStatus &currentEnrollmentStatus);

  bool logEvent(const char *eventType, bool isNetworkAvailable);
  void notifyHardwareAction();
  FirebaseManager();

private:
  static constexpr uint8_t MAX_PENDING_LAST_USED = 8;
  PendingLastUsedUpdate _lastUsedQueue[MAX_PENDING_LAST_USED];
  uint8_t _lastUsedHead = 0;
  uint8_t _lastUsedTail = 0;
  uint8_t _lastUsedCount = 0;
  void enqueueLastUsedUpdate(uint16_t slotId, time_t timestamp);
  void flushPendingLastUsedUpdates(bool isNetworkAvailable);
  bool _hasSyncedFingerprints = false;
  FirebaseData _reqData;
  FirebaseAuth _auth;
  FirebaseConfig _config;
  bool _isInitialized = false;
  unsigned long _lastHardwareActionMs = 0;
  FirebaseStreamHandler _streamHandler;
  FirebaseStateSync _stateSync;
  FirebaseHeartbeat _heartbeat;
  FirebaseLogger _logger;
};