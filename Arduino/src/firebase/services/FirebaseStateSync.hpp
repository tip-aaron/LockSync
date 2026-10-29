#pragma once

#include "constants/common.hpp"
#include <Arduino.h>
#include <cstddef>

using std::nullptr_t;

#include <Firebase_ESP_Client.h>
#include <constants/firebase.hpp>

class FirebaseStateSync {
public:
  void tick(FirebaseData &reqData, bool &currentLockState,
            uint16_t &unauthorizedCount,
            constants::EnrollmentStatus &currentEnrollmentStatus,
            bool isNetworkAvailable);
  void invalidateSync() { _isCloudInSync = false; }

private:
  uint16_t _lastSyncedUnauthorizedCount = 0;
  constants::EnrollmentStatus _lastSyncedEnrollmentStatus =
      constants::EnrollmentStatus::IDLE;
  bool _isCloudInSync = false;
  bool _lastSyncedLockState = false;

  void fetchCloudState(FirebaseData &reqData, bool &currentLockState,
                       uint16_t &unauthorizedCount,
                       constants::EnrollmentStatus &currentEnrollmentStatus);

  bool updateLockState(FirebaseData &reqData, bool isLocked,
                       bool isNetworkAvailable);
  bool updateEnrollmentStatus(FirebaseData &reqData,
                              constants::EnrollmentStatus status,
                              bool isNetworkAvailable);
  bool updateUnauthorizedCount(FirebaseData &reqData, uint16_t count,
                               bool isNetworkAvailable);
};