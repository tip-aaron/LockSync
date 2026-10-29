#pragma once

#include <Arduino.h>
#include <constants/firebase.hpp>
#include <cstddef>

using std::nullptr_t;

#include <Firebase_ESP_Client.h>
#include <functional>

class FirebaseStreamHandler {
public:
  using LockCommandCallback = std::function<void(bool shouldLock)>;
  using EnrollCommandCallback = std::function<void(uint16_t slotId)>;
  using DeleteCommandCallback = std::function<void(int16_t slotId)>;
  using CancelEnrollCallback = std::function<void()>;
  using ResetAlarmCallback = std::function<void()>;

  FirebaseStreamHandler(FirebaseData *reqData);

  void begin(LockCommandCallback onLock, EnrollCommandCallback onEnroll,
             DeleteCommandCallback onDelete, CancelEnrollCallback onCancel,
             ResetAlarmCallback onResetAlarm);

  void tick(bool isNetworkAvailable);
  void stopStream();

private:
  static FirebaseStreamHandler *_instance;

  FirebaseData _streamData;
  FirebaseData *_reqDataPtr = nullptr;

  bool _isStreamActive = false;
  bool _pendingAckReset = false;

  // Deferred command state to prevent blocking inside the stream callback
  constants::CommandAction _pendingAction = constants::CommandAction::IDLE;
  bool _hasPendingCommand = false;

  LockCommandCallback _lockCallback = nullptr;
  EnrollCommandCallback _enrollCallback = nullptr;
  DeleteCommandCallback _deleteCallback = nullptr;
  CancelEnrollCallback _cancelEnrollCallback = nullptr;
  ResetAlarmCallback _resetAlarmCallback = nullptr;

  void setupStream(bool isNetworkAvailable);
  static void streamCallback(FirebaseStream data);
  static void streamTimeoutCallback(bool timeout);
};