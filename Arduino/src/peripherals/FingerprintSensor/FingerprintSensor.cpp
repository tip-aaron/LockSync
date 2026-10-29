#include "FingerprintSensor.hpp"
#include "constants/peripherals.hpp"

FingerprintSensor::FingerprintSensor(HardwareSerial &serialPort, uint8_t rxPin,
                                     uint8_t txPin)
    : _serial(serialPort), _rxPin(rxPin), _txPin(txPin), _finger(&_serial) {}

bool FingerprintSensor::begin() {
  _serial.begin(constants::FINGERPRINT_BAUD_RATE, SERIAL_8N1, _rxPin, _txPin);
  delay(100);
  _finger.begin(constants::FINGERPRINT_BAUD_RATE);

  _finger.setSecurityLevel(4);

  if (_finger.verifyPassword()) {
    Serial.println("[SENSOR] AS608 Fingerprint sensor detected successfully.");

    return true;
  } else {
    Serial.println(
        "[SENSOR ERROR] Did not find AS608 fingerprint sensor. Check wiring!");

    return false;
  }
}

bool FingerprintSensor::hasModel(uint16_t slotId) {
  return (_finger.loadModel(slotId) == FINGERPRINT_OK);
}

bool FingerprintSensor::enrollStep1() {
  int p = _finger.getImage();

  if (p != FINGERPRINT_OK) {
    return false;
  }

  p = _finger.image2Tz(1);

  return (p == FINGERPRINT_OK);
}

bool FingerprintSensor::enrollStep2() {
  int p = _finger.getImage();

  if (p != FINGERPRINT_OK) {
    return false;
  }

  p = _finger.image2Tz(2);

  if (p != FINGERPRINT_OK) {
    return false;
  }

  // Combines image 1 and 2 into a template model in the sensor buffer
  p = _finger.createModel();

  return (p == FINGERPRINT_OK);
}

bool FingerprintSensor::storeModel(uint16_t slotId) {
  int p = _finger.storeModel(slotId);

  return (p == FINGERPRINT_OK);
}

bool FingerprintSensor::deleteSlot(int16_t slotId) {
  if (slotId == -1) {
    return (_finger.emptyDatabase() == FINGERPRINT_OK);
  } else {
    return (_finger.deleteModel(slotId) == FINGERPRINT_OK);
  }
}

bool FingerprintSensor::waitForScan(bool (FingerprintSensor::*scanFunc)()) {
  unsigned long startTime = millis();

  while (millis() - startTime < constants::FINGERPRINT_TIMEOUT_MS) {
    // If user canceled via cloud command, abort immediately
    if (locker_state::enrollmentStatus ==
        constants::EnrollmentStatus::CANCELLED) {
      return false;
    }

    // Execute the passed scan function (enrollStep1 or enrollStep2)
    if ((this->*scanFunc)()) {
      return true;
    }

    // Yield control briefly to prevent WDT triggers and let background tasks
    // tick
    delay(constants::FINGERPRINT_POLL_INTERVAL_MS);
  }

  return false;
}

int FingerprintSensor::search() {
  if (_finger.getImage() != FINGERPRINT_OK) {
    return -1;
  }

  if (_finger.image2Tz() != FINGERPRINT_OK) {
    return -1;
  }

  if (_finger.fingerFastSearch() != FINGERPRINT_OK) {
    return -1;
  }

  Serial.printf("[SENSOR] Match found! ID #%u (Confidence: %u)\n",
                _finger.fingerID, _finger.confidence);

  return _finger.fingerID;
}

FingerScanResult FingerprintSensor::classifyScan(uint16_t &matchedId) {
  uint8_t imgErr = _finger.getImage();
  
  // 1. Check if the sensor is simply idle (no finger present)
  if (imgErr == FINGERPRINT_NOFINGER) {
    return FingerScanResult::NO_FINGER;
  }
  
  if (imgErr != FINGERPRINT_OK) {
    return FingerScanResult::ERROR;
  }

  if (_finger.image2Tz() != FINGERPRINT_OK) {
    return FingerScanResult::ERROR;
  }

  uint8_t searchErr = _finger.fingerFastSearch();
  
  // 2. Valid match found
  if (searchErr == FINGERPRINT_OK) {
    matchedId = _finger.fingerID;
    Serial.printf("[SENSOR] Match found! ID #%u (Confidence: %u)\n", matchedId, _finger.confidence);
    return FingerScanResult::MATCHED;
  } 
  
  // 3. Finger was pressed, but it's an unknown/unauthorized template
  if (searchErr == FINGERPRINT_NOTFOUND) {
    Serial.println("[SENSOR] Finger pressed, but no matching template found (Unauthorized).");
    return FingerScanResult::UNAUTHORIZED;
  }

  return FingerScanResult::ERROR;
}

uint8_t FingerprintSensor::getEnrolledSlotCount() {
  return _finger.getTemplateCount();
}
