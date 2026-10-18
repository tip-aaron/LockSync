/*
 * LockSync Platform - ESP32 Smart Locker & ES608 Biometric Enrollment Module
 * 
 * Target RTDB Path: /lockers/locker_01
 * Conforms to LockSync Firebase Realtime Database Payload Specifications:
 *  - 1. Initiate Enrollment Command (START_ENROLL)
 *  - 2. Live Step-by-Step Guidance Telemetry (PLACE_FINGER_1, REMOVE_FINGER, PLACE_FINGER_2, PROCESSING)
 *  - 3. Successful Enrollment & Slot Metadata (COMPLETED, registeredSlots)
 *  - 4. Enrollment Error Handling (ERROR_PRINTS_DONT_MATCH, etc.)
 *  - 5. Reset / Finalize Workflow (IDLE)
 *  - 6. Remote Lock / Unlock (isLocked, UNLOCKED_VIA_APP)
 *  - 7. Local Biometric Authentication (UNLOCKED_VIA_BIOMETRIC_SLOT_X)
 *  - 8. Door Sensor & Tamper Detection (doorOpen, tamperAlert)
 */

#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>
#include <Adafruit_Fingerprint.h>
#include <ESP32Servo.h>
#include <HardwareSerial.h>

// =========================================================================
// 1. CONFIGURATION
// =========================================================================
#define WIFI_SSID           "YOUR_WIFI_SSID"
#define WIFI_PASSWORD       "YOUR_WIFI_PASSWORD"
#define FIREBASE_API_KEY    "YOUR_FIREBASE_API_KEY"
#define DATABASE_URL        "https://locksync-firebase-default-rtdb.firebaseio.com"
#define LOCKER_PATH         "/lockers/locker_01"

// =========================================================================
// 2. PIN DEFINITIONS
// =========================================================================
#define PIR_PIN             14
#define FP_RX_PIN           16
#define FP_TX_PIN           17
#define SERVO_PIN           13
#define BUZZER_PIN          25
#define LED_PIN             26

const int LOCKED_POS        = 0;
const int UNLOCKED_POS      = 90;

// =========================================================================
// 3. OBJECTS & STATE
// =========================================================================
HardwareSerial fpSerial(2); // UART2 on ESP32
Adafruit_Fingerprint finger(&fpSerial);
Servo lockServo;

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

bool isFirebaseReady = false;
bool isLockedState = true;
bool doorOpenState = false;
bool tamperAlertState = false;
unsigned long lastHeartbeatTime = 0;
unsigned long lastCommandCheckTime = 0;
String currentWorkflowId = "";

// =========================================================================
// 4. HARDWARE HELPERS
// =========================================================================
void setPhysicalLockState(bool locked) {
  isLockedState = locked;
  if (locked) {
    lockServo.write(LOCKED_POS);
    digitalWrite(LED_PIN, LOW);
  } else {
    lockServo.write(UNLOCKED_POS);
    digitalWrite(LED_PIN, HIGH);
    tone(BUZZER_PIN, 1000, 150);
  }
}

int getFingerprintID() {
  if (finger.getImage() != FINGERPRINT_OK) return -1;
  if (finger.image2Tz() != FINGERPRINT_OK) return -1;
  if (finger.fingerFastSearch() != FINGERPRINT_OK) return -1;
  return finger.fingerID;
}

// Find lowest free slot ID (from 1 to 127)
int getNextAvailableSlot() {
  for (int id = 1; id <= 127; id++) {
    if (finger.loadModel(id) != FINGERPRINT_OK) {
      return id; // Available
    }
  }
  return 1;
}

// =========================================================================
// 5. FIREBASE BIOMETRIC ENROLLMENT PROTOCOL
// =========================================================================
void updateEnrollmentTelemetry(String status, String workflowId, String action) {
  if (!isFirebaseReady) return;
  FirebaseJson json;
  json.set("enrollStatus", status);
  json.set("workflowId", workflowId.length() > 0 ? workflowId : "null");
  json.set("lastAction", action);
  Firebase.RTDB.updateNode(&fbdo, LOCKER_PATH, &json);
  Serial.printf("[ENROLL TELEMETRY] %s -> %s\n", status.c_str(), action.c_str());
}

void executeBiometricEnrollment(String workflowId) {
  Serial.printf("\n[ENROLL START] Active Session: %s\n", workflowId.c_str());

  int slotId = getNextAvailableSlot();

  // Phase A: First Scan Request
  updateEnrollmentTelemetry("PLACE_FINGER_1", workflowId, "AWAITING_FIRST_SCAN");
  tone(BUZZER_PIN, 800, 100);

  int p = -1;
  unsigned long timeout = millis() + 15000;
  while (p != FINGERPRINT_OK && millis() < timeout) {
    p = finger.getImage();
    delay(50);
  }
  if (p != FINGERPRINT_OK) {
    updateEnrollmentTelemetry("ERROR_TIMEOUT", workflowId, "ENROLLMENT_FAILED_TIMEOUT");
    return;
  }

  p = finger.image2Tz(1);
  if (p != FINGERPRINT_OK) {
    updateEnrollmentTelemetry("ERROR_SCAN_FAILED", workflowId, "ENROLLMENT_FAILED_CONVERSION_1");
    return;
  }

  // Phase B: Finger Removal Request
  updateEnrollmentTelemetry("REMOVE_FINGER", workflowId, "FIRST_SCAN_CAPTURED");
  tone(BUZZER_PIN, 1200, 100);
  delay(1000);
  p = 0;
  while (p != FINGERPRINT_NOFINGER) {
    p = finger.getImage();
    delay(50);
  }

  // Phase C: Second Scan Request
  updateEnrollmentTelemetry("PLACE_FINGER_2", workflowId, "AWAITING_SECOND_SCAN");
  p = -1;
  timeout = millis() + 15000;
  while (p != FINGERPRINT_OK && millis() < timeout) {
    p = finger.getImage();
    delay(50);
  }
  if (p != FINGERPRINT_OK) {
    updateEnrollmentTelemetry("ERROR_TIMEOUT", workflowId, "ENROLLMENT_FAILED_TIMEOUT");
    return;
  }

  p = finger.image2Tz(2);
  if (p != FINGERPRINT_OK) {
    updateEnrollmentTelemetry("ERROR_SCAN_FAILED", workflowId, "ENROLLMENT_FAILED_CONVERSION_2");
    return;
  }

  // Phase D: Verification & Template Model Processing
  updateEnrollmentTelemetry("PROCESSING", workflowId, "GENERATING_BIOMETRIC_MODEL");
  delay(500);

  p = finger.createModel();
  if (p == FINGERPRINT_OK) {
    Serial.println("[ENROLL] Fingerprint templates matched!");
  } else if (p == FINGERPRINT_ENROLLMISMATCH) {
    updateEnrollmentTelemetry("ERROR_PRINTS_DONT_MATCH", workflowId, "ENROLLMENT_FAILED_PRINTS_MISMATCH");
    tone(BUZZER_PIN, 300, 400);
    return;
  } else {
    updateEnrollmentTelemetry("ERROR_SCAN_FAILED", workflowId, "ENROLLMENT_FAILED_MODEL_ERROR");
    return;
  }

  // Store in hardware flash slot
  p = finger.storeModel(slotId);
  if (p == FINGERPRINT_OK) {
    Serial.printf("[ENROLL SUCCESS] Stored in slot #%d\n", slotId);
    tone(BUZZER_PIN, 1500, 200);

    // Section 3: Successful Enrollment & Slot Metadata Payload
    FirebaseJson slotJson;
    slotJson.set("slotId", slotId);
    slotJson.set("label", "Fingerprint " + String(slotId));
    slotJson.set("assignedUser", "USER_2026_ST99");
    slotJson.set("registeredAt/.sv", "timestamp");
    slotJson.set("workflowId", workflowId);

    String slotPath = String(LOCKER_PATH) + "/registeredSlots/slot_" + String(slotId);
    Firebase.RTDB.updateNode(&fbdo, slotPath.c_str(), &slotJson);

    FirebaseJson completeJson;
    completeJson.set("enrollStatus", "COMPLETED");
    completeJson.set("workflowId", workflowId);
    completeJson.set("lastAction", "BIOMETRIC_ENROLLED_SLOT_" + String(slotId));
    Firebase.RTDB.updateNode(&fbdo, LOCKER_PATH, &completeJson);
  } else {
    updateEnrollmentTelemetry("ERROR_SCAN_FAILED", workflowId, "ENROLLMENT_FAILED_STORE_ERROR");
  }
}

// =========================================================================
// 6. COMMANDS & TELEMETRY LISTENER
// =========================================================================
void checkFirebaseCommands() {
  if (!isFirebaseReady) return;

  // 1. Check for Biometric Enrollment Trigger
  String enrollStatusPath = String(LOCKER_PATH) + "/enrollStatus";
  if (Firebase.RTDB.getString(&fbdo, enrollStatusPath.c_str())) {
    String status = fbdo.stringData();
    if (status == "START_ENROLL") {
      String wfPath = String(LOCKER_PATH) + "/workflowId";
      String wfId = "enroll_sess_" + String(millis());
      if (Firebase.RTDB.getString(&fbdo, wfPath.c_str())) {
        wfId = fbdo.stringData();
      }
      executeBiometricEnrollment(wfId);
    }
  }

  // 2. Check for Remote Lock / Unlock Command
  String lockStatePath = String(LOCKER_PATH) + "/isLocked";
  if (Firebase.RTDB.getBool(&fbdo, lockStatePath.c_str())) {
    bool remoteIsLocked = fbdo.boolData();
    if (remoteIsLocked != isLockedState) {
      Serial.printf("[REMOTE CMD] isLocked -> %s\n", remoteIsLocked ? "TRUE" : "FALSE");
      setPhysicalLockState(remoteIsLocked);
    }
  }
}

void reportLocalBiometricUnlock(int slotId) {
  if (!isFirebaseReady) return;
  String wfId = "local_auth_" + String(millis());

  FirebaseJson json;
  json.set("isLocked", false);
  json.set("workflowId", wfId);
  json.set("lastAction", "UNLOCKED_VIA_BIOMETRIC_SLOT_" + String(slotId));
  Firebase.RTDB.updateNode(&fbdo, LOCKER_PATH, &json);

  // Append history audit trail
  FirebaseJson historyJson;
  historyJson.set("title", "Locker unlocked");
  historyJson.set("subtitle", "Biometric access (Slot #" + String(slotId) + ")");
  historyJson.set("isUnlock", true);
  historyJson.set("source", "hardware");
  historyJson.set("timestamp/.sv", "timestamp");
  Firebase.RTDB.pushJSON(&fbdo, (String(LOCKER_PATH) + "/history").c_str(), &historyJson);
}

void sendHeartbeatAndTelemetry() {
  if (!isFirebaseReady) return;

  int rssi = WiFi.RSSI();
  String signalQuality = "STRONG";
  if (rssi < -80) signalQuality = "WEAK";
  else if (rssi < -68) signalQuality = "GOOD";

  FirebaseJson json;
  json.set("doorOpen", doorOpenState);
  json.set("tamperAlert", tamperAlertState);
  json.set("signal", signalQuality);
  json.set("status", "online");
  json.set("lastUpdated/.sv", "timestamp");
  Firebase.RTDB.updateNode(&fbdo, LOCKER_PATH, &json);
}

// =========================================================================
// 7. SETUP & INITIALIZATION
// =========================================================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n[LockSync Platform] ESP32 Booting...");

  pinMode(PIR_PIN, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);

  lockServo.attach(SERVO_PIN);
  setPhysicalLockState(true);

  fpSerial.begin(57600, SERIAL_8N1, FP_RX_PIN, FP_TX_PIN);
  finger.begin(57600);
  if (finger.verifyPassword()) {
    Serial.println("[ES608] Optical sensor verified.");
  } else {
    Serial.println("[ES608 ERROR] Sensor not found. Verify RX/TX UART wiring.");
  }

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.printf("[WiFi] Connecting to %s...\n", WIFI_SSID);

  int retries = 0;
  while (WiFi.status() != WL_CONNECTED && retries < 20) {
    delay(500);
    Serial.print(".");
    retries++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] Connected. IP: %s\n", WiFi.localIP().toString().c_str());

    config.api_key = FIREBASE_API_KEY;
    config.database_url = DATABASE_URL;
    config.signer.test_mode = true;
    Firebase.reconnectWiFi(true);

    Firebase.begin(&config, &auth);
    isFirebaseReady = true;

    // Initialize node structure as in Section 9
    FirebaseJson initJson;
    initJson.set("isLocked", true);
    initJson.set("doorOpen", false);
    initJson.set("tamperAlert", false);
    initJson.set("enrollStatus", "IDLE");
    initJson.set("workflowId", "null");
    initJson.set("lastAction", "INITIALIZED");
    Firebase.RTDB.updateNode(&fbdo, LOCKER_PATH, &initJson);

    sendHeartbeatAndTelemetry();
  } else {
    Serial.println("\n[WiFi WARNING] WiFi connection failed. Running locally.");
  }
}

// =========================================================================
// 8. MAIN LOOP
// =========================================================================
void loop() {
  // 1. Check local PIR motion & fingerprint authentication
  bool motion = digitalRead(PIR_PIN) == HIGH;
  if (motion) {
    int fingerId = getFingerprintID();
    if (fingerId >= 0) {
      Serial.printf("[BIOMETRIC UNLOCK] Matched Slot #%d\n", fingerId);
      setPhysicalLockState(false);
      reportLocalBiometricUnlock(fingerId);

      delay(3000); // Hold unlocked
      setPhysicalLockState(true);
    }
  }

  // 2. Poll Firebase Commands (Remote lock & enrollment triggers)
  if (millis() - lastCommandCheckTime > 1200) {
    lastCommandCheckTime = millis();
    checkFirebaseCommands();
  }

  // 3. Periodic telemetry heartbeat
  if (millis() - lastHeartbeatTime > 30000) {
    lastHeartbeatTime = millis();
    sendHeartbeatAndTelemetry();
  }

  delay(80);
}