#include "firebase/services/FirebaseStreamHandler.hpp"
#include "constants/firebase.hpp"

FirebaseStreamHandler *FirebaseStreamHandler::_instance = nullptr;

FirebaseStreamHandler::FirebaseStreamHandler(FirebaseData *_reqData) {
  _instance = this;
  _reqDataPtr = _reqData;
}

void FirebaseStreamHandler::begin(LockCommandCallback onLock,
                                  EnrollCommandCallback onEnroll,
                                  DeleteCommandCallback onDelete,
                                  CancelEnrollCallback onCancel,
                                  ResetAlarmCallback onResetAlarm) {
  _lockCallback = onLock;
  _enrollCallback = onEnroll;
  _deleteCallback = onDelete;
  _cancelEnrollCallback = onCancel;
  _resetAlarmCallback = onResetAlarm;

  _streamData.setBSSLBufferSize(4096, 1024);
  _streamData.setResponseSize(constants::FIREBASE_STREAM_BUFFER_SIZE);
}

void FirebaseStreamHandler::tick(bool isNetworkAvailable) {
  if (!isNetworkAvailable || !Firebase.ready()) {
    if (_isStreamActive) {
      stopStream();
    }
    return;
  }

  if (!_isStreamActive) {
    setupStream(isNetworkAvailable);
  }

  // Process pending ACK reset if a network drop interrupted an earlier
  // acknowledgment
  if (_pendingAckReset && isNetworkAvailable) {
    if (Firebase.RTDB.setInt(
            _reqDataPtr, constants::DB_PATH_CMD_ACTION,
            static_cast<int>(constants::CommandAction::IDLE))) {
      Firebase.RTDB.setInt(_reqDataPtr, constants::DB_PATH_CMD_PARAM, 0);
      _pendingAckReset = false;
      Serial.println(
          "[STREAM] Pending command ACK & PARAM successfully reset to IDLE.");
    }
  }

  // Process any pending command captured safely from the stream callback
  if (_hasPendingCommand && isNetworkAvailable) {
    constants::CommandAction action = _pendingAction;
    _hasPendingCommand = false; // Reset flag immediately

    switch (action) {
    case constants::CommandAction::IDLE:
      break;

    case constants::CommandAction::LOCK:
      Serial.println("[COMMAND] Primitive Action: LOCK");
      if (_lockCallback) {
        _lockCallback(true);
      }
      break;

    case constants::CommandAction::UNLOCK:
      Serial.println("[COMMAND] Primitive Action: UNLOCK");
      if (_lockCallback) {
        _lockCallback(false);
      }
      break;

    case constants::CommandAction::ENROLL_FINGERPRINT: {
      int slotId = 0;
      if (Firebase.RTDB.getInt(_reqDataPtr, constants::DB_PATH_CMD_PARAM)) {
        slotId = _reqDataPtr->intData();
      }
      Serial.printf("[COMMAND] Primitive Action: ENROLL ID %d\n", slotId);
      if (_enrollCallback && slotId > 0) {
        _enrollCallback(static_cast<uint16_t>(slotId));
      }
      break;
    }

    case constants::CommandAction::DELETE_FINGERPRINT: {
      int slotId = 0;
      bool hasParam = false;

      // Safely read param regardless of whether RTDB stored it as int or string
      if (Firebase.RTDB.get(_reqDataPtr, constants::DB_PATH_CMD_PARAM)) {
        if (_reqDataPtr->dataType() == "int") {
          slotId = _reqDataPtr->intData();
          hasParam = true;
        } else if (_reqDataPtr->dataType() == "string") {
          slotId = atoi(_reqDataPtr->stringData().c_str());
          hasParam = true;
        }
      }

      Serial.printf("[COMMAND] Primitive Action: DELETE ID %d\n", slotId);

      // Validate slot boundaries (1-162) or explicit purge (-1) before
      // executing
      if (_deleteCallback && hasParam && (slotId > 0 || slotId == -1)) {
        _deleteCallback(static_cast<int16_t>(slotId));
      } else {
        Serial.printf(
            "[STREAM ERROR] Invalid or unreadable delete param (slotId=%d)\n",
            slotId);
      }
      break;
    }

    case constants::CommandAction::CANCEL_ENROLLMENT:
      Serial.println("[COMMAND] Primitive Action: CANCEL ENROLLMENT");
      if (_cancelEnrollCallback) {
        _cancelEnrollCallback();
      }
      break;

    case constants::CommandAction::RESET_UNAUTHORIZED:
      Serial.println("[COMMAND] Primitive Action: RESET UNAUTHORIZED / DISARM");
      if (_resetAlarmCallback) {
        _resetAlarmCallback();
      }
      break;

    default:
      Serial.printf("[STREAM WARNING] Unknown action code: %d\n",
                    static_cast<int>(action));
      break;
    }

    // Acknowledge action back to IDLE safely on the main loop thread
    bool ackSuccess =
        Firebase.RTDB.setInt(_reqDataPtr, constants::DB_PATH_CMD_ACTION,
                             static_cast<int>(constants::CommandAction::IDLE));

    if (ackSuccess) {
      // Clear parameter payload on successful ACK
      Firebase.RTDB.setInt(_reqDataPtr, constants::DB_PATH_CMD_PARAM, 0);
    } else {
      _pendingAckReset = true;
      Serial.println("[STREAM WARNING] Command ACK failed. Queued for retry.");
    }
  }
}

void FirebaseStreamHandler::stopStream() {
  Firebase.RTDB.endStream(&_streamData);
  _isStreamActive = false;
  Serial.println("[STREAM] Stream socket explicitly closed (Offline).");
}

void FirebaseStreamHandler::setupStream(bool isNetworkAvailable) {
  if (!isNetworkAvailable) {
    return;
  }

  Firebase.RTDB.endStream(&_streamData);
  Serial.printf("[STREAM] Listening to primitive leaf: %s\n",
                constants::DB_PATH_CMD_ACTION);

  if (Firebase.RTDB.beginStream(&_streamData, constants::DB_PATH_CMD_ACTION)) {
    Firebase.RTDB.setStreamCallback(&_streamData, streamCallback,
                                    streamTimeoutCallback);
    _isStreamActive = true;
    Serial.println("[STREAM] Primitive stream listener active.");
  } else {
    Serial.printf("[STREAM ERROR] Setup failed: %s\n",
                  _streamData.errorReason().c_str());
  }
}

void FirebaseStreamHandler::streamCallback(FirebaseStream data) {
  if (!_instance) {
    return;
  }

  Serial.printf("[STREAM] Event | Payload: %u bytes | Type: %s\n",
                data.payloadLength(), data.dataType().c_str());

  if (data.dataType() == "int") {
    const auto action = static_cast<constants::CommandAction>(data.intData());
    if (action != constants::CommandAction::IDLE) {
      // Safely capture action for processing in tick() — DO NOT make network
      // calls here!
      _instance->_pendingAction = action;
      _instance->_hasPendingCommand = true;
    }
  }
}

void FirebaseStreamHandler::streamTimeoutCallback(bool timeout) {
  if (timeout) {
    Serial.println("[STREAM] Connection timed out. Reconnecting...");
  }
}