#pragma once

#include <Arduino.h>
#include <cstddef>

using std::nullptr_t;

#include <Firebase_ESP_Client.h>
#include <constants/firebase.hpp>

class FirebaseHeartbeat {
public:
  void tick(FirebaseData &reqData, bool isNetworkAvailable);
  bool sendHeartbeat(FirebaseData &reqData, bool isNetworkAvailable);

private:
  uint32_t _lastHeartbeatTimestamp = 0;
};