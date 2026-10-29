#pragma once

#include <Adafruit_Fingerprint.h>
#include <Arduino.h>
#include <constants/common.hpp>
#include <constants/state.hpp>

enum class FingerScanResult { NO_FINGER, MATCHED, UNAUTHORIZED, ERROR };

class FingerprintSensor {
public:
  FingerprintSensor(HardwareSerial &serialPort, uint8_t rxPin, uint8_t txPin);

  bool begin();
  bool enrollStep1();
  bool enrollStep2();               // Converts 2nd image & creates model
  bool storeModel(uint16_t slotId); // Saves created model to flash storage
  int search();
  FingerScanResult
  classifyScan(uint16_t &matchedId); // New classifier for unauthorized tracking
  bool deleteSlot(int16_t slotId);
  uint8_t getEnrolledSlotCount();
bool hasModel(uint16_t slotId);
  // Helper method to block/poll until a scan step succeeds or times out
  bool waitForScan(bool (FingerprintSensor::*scanFunc)());

private:
  HardwareSerial &_serial;
  uint8_t _rxPin;
  uint8_t _txPin;
  Adafruit_Fingerprint _finger;
};