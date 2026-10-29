#include "firebase/services/FirebaseStateSync.hpp"

void FirebaseStateSync::tick(
    FirebaseData &reqData, bool &currentLockState, uint16_t &unauthorizedCount,
    constants::EnrollmentStatus &currentEnrollmentStatus,
    bool isNetworkAvailable) {
  if (!isNetworkAvailable || !Firebase.ready()) {
    _isCloudInSync = false;
    return;
  }

  // --- RECONNECT RECONCILIATION ---
  // Pull authoritative state from Firebase first so local state adopts cloud reality 
  // (preventing local defaults from wiping out cloud records like unauthorized attempts).
  if (!_isCloudInSync) {
    fetchCloudState(reqData, currentLockState, unauthorizedCount, currentEnrollmentStatus);
    _isCloudInSync = true;
    _lastSyncedLockState = currentLockState;
    _lastSyncedUnauthorizedCount = unauthorizedCount;
    _lastSyncedEnrollmentStatus = currentEnrollmentStatus;
    return; 
  }

  if (currentLockState != _lastSyncedLockState) {
    updateLockState(reqData, currentLockState, isNetworkAvailable);
  }

  if (unauthorizedCount != _lastSyncedUnauthorizedCount) {
    updateUnauthorizedCount(reqData, unauthorizedCount, isNetworkAvailable);
  }

  if (currentEnrollmentStatus != _lastSyncedEnrollmentStatus) {
    updateEnrollmentStatus(reqData, currentEnrollmentStatus,
                           isNetworkAvailable);
  }
}

void FirebaseStateSync::fetchCloudState(
    FirebaseData &reqData, bool &currentLockState, uint16_t &unauthorizedCount,
    constants::EnrollmentStatus &currentEnrollmentStatus) {
  Serial.println("[SYNC] Reconnected. Fetching authoritative state from cloud...");

  // 1. Fetch Lock Status
  if (Firebase.RTDB.getBool(&reqData, constants::DB_PATH_LOCK_STATUS)) {
    currentLockState = reqData.boolData();
    Serial.printf("[SYNC] Cloud lock status adopted: %s\n", currentLockState ? "LOCKED" : "UNLOCKED");
  } else {
    Firebase.RTDB.setBool(&reqData, constants::DB_PATH_LOCK_STATUS, currentLockState);
  }

  // 2. Fetch Unauthorized Count (Preserves offline alarm counts!)
  if (Firebase.RTDB.getInt(&reqData, constants::DB_PATH_UNAUTHORIZED_COUNT)) {
    unauthorizedCount = static_cast<uint16_t>(reqData.intData());
    Serial.printf("[SYNC] Cloud unauthorized count adopted: %u\n", unauthorizedCount);
  } else {
    Firebase.RTDB.setInt(&reqData, constants::DB_PATH_UNAUTHORIZED_COUNT, unauthorizedCount);
  }

  // 3. Fetch Enrollment Status
  if (Firebase.RTDB.getString(&reqData, constants::DB_PATH_ENROLL_STATUS)) {
    Serial.printf("[SYNC] Cloud enrollment status node exists.\n");
  } else {
    Firebase.RTDB.setString(&reqData, constants::DB_PATH_ENROLL_STATUS,
                            constants::enrollmentStatusToString(currentEnrollmentStatus));
  }
}

bool FirebaseStateSync::updateLockState(FirebaseData &reqData, bool isLocked,
                                        bool isNetworkAvailable) {
  if (!isNetworkAvailable) {
    return false;
  }

  bool success =
      Firebase.RTDB.setBool(&reqData, constants::DB_PATH_LOCK_STATUS, isLocked);

  if (success) {
    _isCloudInSync = true;
    _lastSyncedLockState = isLocked;

    Serial.printf("[SYNC] Lock status synced: %s\n",
                  isLocked ? "LOCKED" : "UNLOCKED");
  } else {
    _isCloudInSync = false;

    Serial.printf("[SYNC ERROR] Status sync failed: %s\n",
                  reqData.errorReason().c_str());
  }

  return success;
}

bool FirebaseStateSync::updateEnrollmentStatus(
    FirebaseData &reqData, constants::EnrollmentStatus status,
    bool isNetworkAvailable) {
  if (!isNetworkAvailable) {
    return false;
  }

  const char *statusStr = constants::enrollmentStatusToString(status);
  bool success = Firebase.RTDB.setString(
      &reqData, constants::DB_PATH_ENROLL_STATUS, statusStr);

  if (success) {
    _isCloudInSync = true;
    _lastSyncedEnrollmentStatus = status;

    Serial.printf("[SYNC] Enrollment status synced: %s\n", statusStr);
  } else {
    _isCloudInSync = false;

    Serial.printf("[SYNC ERROR] Enrollment status sync failed: %s\n",
                  reqData.errorReason().c_str());
  }

  return success;
}

bool FirebaseStateSync::updateUnauthorizedCount(FirebaseData &reqData,
                                                uint16_t count,
                                                bool isNetworkAvailable) {
  if (!isNetworkAvailable) {
    return false;
  }

  bool success = Firebase.RTDB.setInt(
      &reqData, constants::DB_PATH_UNAUTHORIZED_COUNT, count);

  if (success) {
    _lastSyncedUnauthorizedCount = count;

    Serial.printf("[SYNC] Unauthorized count synced: %u\n", count);
  }

  return success;
}