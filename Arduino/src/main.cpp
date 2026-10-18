#include <Arduino.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <Adafruit_Fingerprint.h>
#include <HardwareSerial.h>

#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>

// ============================================================================
// 1. NETWORK & CLOUD CREDENTIALS
// ============================================================================
#define WIFI_SSID                   "Wokwi-GUEST"
#define WIFI_PASSWORD               ""
#define API_KEY                     "AIzaSyCwXNa8Ki40gn8W3_QdC6dbiIRkJsILGxA"
#define DATABASE_URL                "https://locksync-ab6fa-default-rtdb.asia-southeast1.firebasedatabase.app"

#define LOCKER_ID                   "locker_01"
const String LOCKER_PATH            = "/lockers/" + String(LOCKER_ID);

// ============================================================================
// 2. HARDWARE PIN DEFINITIONS
// ============================================================================
#define PIR_PIN                     14
#define SERVO_PIN                   13
#define BUZZER_PIN                  25
#define LED_PIN                     26
#define BUTTON_PIN                  27
#define FP_RX_PIN                   16
#define FP_TX_PIN                   17

// ============================================================================
// 3. HARDWARE SPECIFICATIONS & TIMING CONSTANTS
// ============================================================================
constexpr unsigned long SERIAL_BAUD             = 115200;
constexpr unsigned long FP_SERIAL_BAUD          = 57600;

constexpr int SERVO_FREQ_HZ                     = 50;
constexpr int SERVO_RESOLUTION_BITS             = 16;
constexpr int SERVO_MIN_PULSE_US                = 500;
constexpr int SERVO_MAX_PULSE_US                = 2400;
constexpr uint32_t SERVO_PERIOD_US             = 20000;
constexpr uint32_t SERVO_MAX_DUTY               = 65535;
constexpr int SERVO_MAX_ANGLE                   = 180;

constexpr int LOCKED_POS                        = 0;
constexpr int UNLOCKED_POS                      = 90;

constexpr unsigned long BUTTON_DEBOUNCE_MS      = 50;
constexpr unsigned long ENROLL_TIMEOUT_MS       = 25000;
constexpr unsigned long BOOT_STABILIZE_MS       = 3000;
constexpr unsigned long LOOP_DELAY_MS           = 20;
constexpr unsigned long SERIAL_FLUSH_DELAY_MS   = 50;
constexpr unsigned long BOOT_SERIAL_DELAY_MS    = 500;

constexpr int MAX_FINGERPRINT_SLOTS             = 162;
constexpr int SLOT_ARRAY_SIZE                   = MAX_FINGERPRINT_SLOTS + 1;
constexpr int SLOT_INVALID                      = -1;
constexpr int SLOT_CLEAR_TRIGGER                = 0;
constexpr int SLOT_ERROR_TRIGGER                = -1;

constexpr int FP_SEARCH_NOT_FOUND               = -2;
constexpr int FP_SEARCH_ERROR                   = -1;

#define WOKWI_SIMULATION_MODE true

// ============================================================================
// 4. BUZZER FREQUENCIES & DURATIONS
// ============================================================================
constexpr int BEEP_FREQ_ALERT                   = 400;
constexpr int BEEP_FREQ_LOW                     = 800;
constexpr int BEEP_FREQ_MID                     = 1000;
constexpr int BEEP_FREQ_HIGH                    = 1200;
constexpr int BEEP_FREQ_SUCCESS                 = 1500;
constexpr int BEEP_FREQ_COMPLETE                = 2000;

constexpr int BEEP_DUR_SHORT                    = 100;
constexpr int BEEP_DUR_MID                      = 150;
constexpr int BEEP_DUR_LONG                     = 200;
constexpr int BEEP_DUR_ALERT                    = 200;

// ============================================================================
// 5. SERIAL MONITOR COMMAND CHARACTERS
// ============================================================================
constexpr char CMD_SIM_VALID_SCAN               = '1';
constexpr char CMD_SIM_INVALID_SCAN             = '2';
constexpr char CMD_SIM_ENROLL                   = 'e';
constexpr char CMD_SIM_DELETE                   = 'd';

// ============================================================================
// 6. FIREBASE DATABASE PATHS & STATUS STRINGS
// ============================================================================
const String PATH_IS_LOCKED                     = "/isLocked";
const String PATH_DELETE_SLOT                   = "/deleteSlot";
const String PATH_ENROLL_STATUS                 = "/enrollStatus";
const String PATH_MOTION_DETECTED               = "/motionDetected";
const String PATH_LAST_ACTION                   = "/lastAction";
const String PATH_TAMPER_ALERT                  = "/tamperAlert";
const String PATH_REGISTERED_SLOTS              = "/registeredSlots/slot_";
const String PATH_ACTIVE_SLOTS_LIST             = "/activeSlotsList";
const String PATH_ROOT                          = "/";

const String STATUS_IDLE                        = "IDLE";
const String STATUS_START_ENROLL                = "START_ENROLL";
const String STATUS_PLACE_FINGER_1              = "PLACE_FINGER_1";
const String STATUS_PLACE_FINGER_2              = "PLACE_FINGER_2";
const String STATUS_REMOVE_FINGER               = "REMOVE_FINGER";
const String STATUS_PROCESSING                  = "PROCESSING";
const String STATUS_COMPLETED                   = "COMPLETED";
const String STATUS_TIMEOUT                     = "TIMEOUT";
const String STATUS_ERROR_STORAGE               = "ERROR_STORAGE_FAILED";

const String ACTION_LOCKED                      = "LOCKED";
const String ACTION_BUTTON_LOCKED               = "MANUAL_BUTTON_LOCK";
const String ACTION_MOTION_DETECTED             = "MOTION_DETECTED";
const String ACTION_UNAUTHORIZED                = "UNAUTHORIZED_ATTEMPT";
const String ACTION_STORAGE_FULL                = "STORAGE_FULL";
const String ACTION_TIMEOUT                     = "ENROLLMENT_TIMEOUT";
const String ACTION_WRITE_ERR                   = "HARDWARE_WRITE_ERROR";
const String ACTION_AWAITING_SCAN_1             = "AWAITING_FIRST_SCAN";
const String ACTION_AWAITING_SCAN_2             = "AWAITING_SECOND_SCAN";
const String ACTION_AWAITING_REMOVE             = "AWAITING_FINGER_REMOVE";
const String ACTION_VALIDATING                  = "VALIDATING_PRINTS";

const String PREFIX_MATCH_FINGER                = "MATCH_FINGER_ID_";
const String PREFIX_BIOMETRIC_ENROLLED          = "BIOMETRIC_ENROLLED_SLOT_";
const String PREFIX_DELETED_SLOT                = "DELETED_SLOT_";
const String PREFIX_DELETE_ERR_SLOT             = "ERROR_DELETE_FAILED_SLOT_";
const String LABEL_FINGERPRINT_PREFIX           = "Fingerprint ";

// ============================================================================
// 7. GLOBAL OBJECTS & STATE
// ============================================================================
HardwareSerial fpSerial(2);
Adafruit_Fingerprint finger(&fpSerial);

FirebaseData streamData, fbdo;
FirebaseAuth auth;
FirebaseConfig config;

bool isLocked                                   = true;
bool lastMotionState                            = false;
bool lastRawButtonState                         = HIGH;
bool lastStableButtonState                      = HIGH;
unsigned long lastButtonDebounceMs              = 0;
bool firebaseAuthenticated                      = false;
String currentEnrollStatus                      = STATUS_IDLE;
unsigned long bootTimeMs                        = 0;

bool simulatedSlots[SLOT_ARRAY_SIZE]            = { false };

// ============================================================================
// 8. FUNCTION DECLARATIONS
// ============================================================================
void initServoHardware();
void setServoAngle(int angle);
void playBeep(int freq, int durationMs);
void flushSerialBuffer();

void handleSerialCommands();
void handlePIRSensor();
void handleLockButton();
void handleBiometricWorkflow();

void applyLockState(bool targetLocked, String source, bool updateCloud);
void alertUnauthorized();

uint8_t waitForFingerScan();
int getNextFreeSlot();
void processAppEnrollment();
void deleteFingerprintSlot(int slotId);
int getFingerprintID();

void connectWiFi();
void initFirebase();
void streamCallback(FirebaseStream data);
void streamTimeoutCallback(bool timeout);
void updateEnrollStatus(String status, String lastAction = "");
void syncRegisteredSlotsToFirebase();

// ============================================================================
// 9. HARDWARE DRIVERS
// ============================================================================
void initServoHardware() {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcAttach(SERVO_PIN, SERVO_FREQ_HZ, SERVO_RESOLUTION_BITS);
#else
  ledcSetup(0, SERVO_FREQ_HZ, SERVO_RESOLUTION_BITS);
  ledcAttachPin(SERVO_PIN, 0);
#endif
}

void setServoAngle(int angle) {
  int pulseWidthUs = map(angle, 0, SERVO_MAX_ANGLE, SERVO_MIN_PULSE_US, SERVO_MAX_PULSE_US);
  uint32_t duty = (pulseWidthUs * SERVO_MAX_DUTY) / SERVO_PERIOD_US;
#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(SERVO_PIN, duty);
#else
  ledcWrite(0, duty);
#endif
}

void playBeep(int freq, int durationMs) {
  if (freq <= 0) return;
  pinMode(BUZZER_PIN, OUTPUT);
  unsigned long delayUs = 1000000UL / (freq * 2);
  unsigned long start = millis();
  
  while (millis() - start < (unsigned long)durationMs) {
    digitalWrite(BUZZER_PIN, HIGH);
    delayMicroseconds(delayUs);
    digitalWrite(BUZZER_PIN, LOW);
    delayMicroseconds(delayUs);
  }
  digitalWrite(BUZZER_PIN, LOW);
}

void flushSerialBuffer() {
  delay(SERIAL_FLUSH_DELAY_MS);
  while (Serial.available() > 0) {
    Serial.read();
  }
}

// ============================================================================
// 10. SYSTEM INITIALIZATION
// ============================================================================
void setup() {
  digitalWrite(BUZZER_PIN, LOW);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  pinMode(PIR_PIN, INPUT_PULLDOWN);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.begin(SERIAL_BAUD);
  delay(BOOT_SERIAL_DELAY_MS);

  Serial.println("\n==========================================");
  Serial.println("   LockSync - Wokwi Serial Controls:");
  Serial.println("   Press '1' -> Simulate valid scan (Stays Open)");
  Serial.println("   Press '2' -> Simulate unauthorized scan");
  Serial.println("   Press 'e' -> Trigger Enrollment sequence");
  Serial.println("   Press 'd' -> Delete Slot #1");
  Serial.println("   Press Physical Button / GPIO 27 -> Lock Door");
  Serial.println("==========================================\n");

  initServoHardware();
  setServoAngle(LOCKED_POS);
  isLocked = true;

  fpSerial.begin(FP_SERIAL_BAUD, SERIAL_8N1, FP_RX_PIN, FP_TX_PIN);
  finger.begin(FP_SERIAL_BAUD);

  if (finger.verifyPassword()) {
    Serial.println("Fingerprint sensor online.");
  } else {
    Serial.println("Notice: Fingerprint sensor running in Wokwi Simulation Mode.");
  }

  connectWiFi();
  initFirebase();
  syncRegisteredSlotsToFirebase();

  bootTimeMs = millis();
  Serial.println(">>> System Ready <<<");
}

// ============================================================================
// 11. MAIN EXECUTION LOOP
// ============================================================================
void loop() {
  handleSerialCommands();
  handlePIRSensor();
  handleLockButton();
  handleBiometricWorkflow();
  delay(LOOP_DELAY_MS);
}

// ============================================================================
// 12. UNIFIED HARDWARE CONTROL & SECURITY ACTIONS
// ============================================================================
void applyLockState(bool targetLocked, String source, bool updateCloud) {
  if (targetLocked == isLocked) return;

  isLocked = targetLocked;

  if (isLocked) {
    Serial.printf("Lock Engaged (%s)\n", source.c_str());
    setServoAngle(LOCKED_POS);
    digitalWrite(LED_PIN, LOW);
    playBeep(BEEP_FREQ_MID, BEEP_DUR_SHORT);
  } else {
    Serial.printf("Access Granted (%s) - Locker Unlocked\n", source.c_str());
    setServoAngle(UNLOCKED_POS);
    digitalWrite(LED_PIN, HIGH);
    playBeep(BEEP_FREQ_SUCCESS, BEEP_DUR_LONG);
  }

  if (updateCloud && firebaseAuthenticated && Firebase.ready()) {
    FirebaseJson updateJson;
    updateJson.add("isLocked", isLocked);
    updateJson.add("lastAction", source);
    Firebase.RTDB.updateNode(&fbdo, LOCKER_PATH, &updateJson);
  }
}

void alertUnauthorized() {
  Serial.println("Access Denied - Unauthorized Attempt!");
  playBeep(BEEP_FREQ_ALERT, BEEP_DUR_ALERT);
  delay(BEEP_DUR_SHORT);
  playBeep(BEEP_FREQ_ALERT, BEEP_DUR_ALERT);

  if (firebaseAuthenticated && Firebase.ready()) {
    Firebase.RTDB.setString(&fbdo, LOCKER_PATH + PATH_LAST_ACTION, ACTION_UNAUTHORIZED);
    Firebase.RTDB.setBool(&fbdo, LOCKER_PATH + PATH_TAMPER_ALERT, true);
  }
}

// ============================================================================
// 13. INPUT & WORKFLOW HANDLERS
// ============================================================================
void handleSerialCommands() {
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    if (cmd == CMD_SIM_VALID_SCAN) {
      Serial.println("[Simulated] Valid fingerprint scanned (ID #1)");
      applyLockState(false, PREFIX_MATCH_FINGER + String(1), true);
    } else if (cmd == CMD_SIM_INVALID_SCAN) {
      Serial.println("[Simulated] Fingerprint mismatch!");
      alertUnauthorized();
    } else if (cmd == CMD_SIM_ENROLL) {
      Serial.println("[Simulated] Initiating enrollment...");
      currentEnrollStatus = STATUS_START_ENROLL;
    } else if (cmd == CMD_SIM_DELETE) {
      Serial.println("[Simulated] Deleting fingerprint Slot #1...");
      deleteFingerprintSlot(1);
    }
  }
}

void handlePIRSensor() {
  if (millis() - bootTimeMs <= BOOT_STABILIZE_MS) return;

  bool currentMotion = (digitalRead(PIR_PIN) == HIGH);
  if (currentMotion && !lastMotionState) {
    Serial.println("PIR: Motion detected near locker!");
    if (firebaseAuthenticated && Firebase.ready()) {
      Firebase.RTDB.setBool(&fbdo, LOCKER_PATH + PATH_MOTION_DETECTED, true);
      Firebase.RTDB.setString(&fbdo, LOCKER_PATH + PATH_LAST_ACTION, ACTION_MOTION_DETECTED);
    }
  } else if (!currentMotion && lastMotionState) {
    Serial.println("PIR: Motion stopped.");
    if (firebaseAuthenticated && Firebase.ready()) {
      Firebase.RTDB.setBool(&fbdo, LOCKER_PATH + PATH_MOTION_DETECTED, false);
    }
  }
  lastMotionState = currentMotion;
}

void handleLockButton() {
  bool reading = digitalRead(BUTTON_PIN);

  if (reading != lastRawButtonState) {
    lastButtonDebounceMs = millis();
    lastRawButtonState = reading;
  }

  if ((millis() - lastButtonDebounceMs) > BUTTON_DEBOUNCE_MS) {
    if (reading != lastStableButtonState) {
      lastStableButtonState = reading;
      if (lastStableButtonState == LOW && !isLocked) {
        Serial.println("Physical Lock Button Pressed!");
        applyLockState(true, ACTION_BUTTON_LOCKED, true);
      }
    }
  }
}

void handleBiometricWorkflow() {
  if (currentEnrollStatus == STATUS_START_ENROLL) {
    processAppEnrollment();
  } else if (currentEnrollStatus == STATUS_IDLE && !WOKWI_SIMULATION_MODE) {
    int id = getFingerprintID();
    if (id >= 0) {
      applyLockState(false, PREFIX_MATCH_FINGER + String(id), true);
    } else if (id == FP_SEARCH_NOT_FOUND) {
      alertUnauthorized();
    }
  }
}

// ============================================================================
// 14. BIOMETRIC ENROLLMENT & DELETION LOGIC
// ============================================================================
uint8_t waitForFingerScan() {
  flushSerialBuffer();
  
  unsigned long start = millis();
  while (millis() - start < ENROLL_TIMEOUT_MS) {
    if (!WOKWI_SIMULATION_MODE) {
      if (finger.getImage() == FINGERPRINT_OK) return FINGERPRINT_OK;
    }
    if (Serial.available() > 0) {
      char c = Serial.read();
      if (c == CMD_SIM_VALID_SCAN) {
        flushSerialBuffer();
        return FINGERPRINT_OK;
      }
    }
    delay(LOOP_DELAY_MS);
  }
  return FINGERPRINT_TIMEOUT;
}

int getNextFreeSlot() {
  if (WOKWI_SIMULATION_MODE) {
    for (int slot = 1; slot <= MAX_FINGERPRINT_SLOTS; slot++) {
      if (!simulatedSlots[slot]) return slot;
    }
    return SLOT_INVALID;
  }

  finger.getTemplateCount();
  for (int slot = 1; slot <= MAX_FINGERPRINT_SLOTS; slot++) {
    if (finger.loadModel(slot) != FINGERPRINT_OK) return slot;
  }
  return SLOT_INVALID;
}

void processAppEnrollment() {
  int targetSlot = getNextFreeSlot();
  if (targetSlot < 0) {
    Serial.println("Error: No available slots remaining!");
    updateEnrollStatus(STATUS_ERROR_STORAGE, ACTION_STORAGE_FULL);
    updateEnrollStatus(STATUS_IDLE, ACTION_STORAGE_FULL);
    currentEnrollStatus = STATUS_IDLE;
    return;
  }

  Serial.printf("Starting enrollment for target Slot #%d\n", targetSlot);

  // First Scan Step
  updateEnrollStatus(STATUS_PLACE_FINGER_1, ACTION_AWAITING_SCAN_1);
  playBeep(BEEP_FREQ_MID, BEEP_DUR_SHORT);
  Serial.println("[Prompt] Type '1' and press Enter for 1st scan...");

  if (waitForFingerScan() != FINGERPRINT_OK) {
    updateEnrollStatus(STATUS_TIMEOUT, ACTION_TIMEOUT);
    updateEnrollStatus(STATUS_IDLE, ACTION_TIMEOUT);
    currentEnrollStatus = STATUS_IDLE;
    return;
  }

  updateEnrollStatus(STATUS_REMOVE_FINGER, ACTION_AWAITING_REMOVE);
  playBeep(BEEP_FREQ_HIGH, BEEP_DUR_SHORT);
  delay(1000);

  // Second Scan Step
  updateEnrollStatus(STATUS_PLACE_FINGER_2, ACTION_AWAITING_SCAN_2);
  playBeep(BEEP_FREQ_MID, BEEP_DUR_SHORT);
  Serial.println("[Prompt] Type '1' and press Enter for 2nd scan...");

  if (waitForFingerScan() != FINGERPRINT_OK) {
    updateEnrollStatus(STATUS_TIMEOUT, ACTION_TIMEOUT);
    updateEnrollStatus(STATUS_IDLE, ACTION_TIMEOUT);
    currentEnrollStatus = STATUS_IDLE;
    return;
  }

  updateEnrollStatus(STATUS_PROCESSING, ACTION_VALIDATING);

  int p = WOKWI_SIMULATION_MODE ? FINGERPRINT_OK : finger.storeModel(targetSlot);
  if (p == FINGERPRINT_OK) {
    if (WOKWI_SIMULATION_MODE) simulatedSlots[targetSlot] = true;

    Serial.printf("SUCCESS! Stored fingerprint in Slot #%d\n", targetSlot);

    if (firebaseAuthenticated && Firebase.ready()) {
      String slotNode = LOCKER_PATH + PATH_REGISTERED_SLOTS + String(targetSlot);
      Firebase.RTDB.setInt(&fbdo, slotNode + "/slotId", targetSlot);
      Firebase.RTDB.setString(&fbdo, slotNode + "/label", LABEL_FINGERPRINT_PREFIX + String(targetSlot));
      Firebase.RTDB.setInt(&fbdo, slotNode + "/registeredAt", millis());
    }

    playBeep(BEEP_FREQ_SUCCESS, BEEP_DUR_MID);
    delay(BEEP_DUR_MID);
    playBeep(BEEP_FREQ_COMPLETE, BEEP_DUR_LONG);

    updateEnrollStatus(STATUS_COMPLETED, PREFIX_BIOMETRIC_ENROLLED + String(targetSlot));
    syncRegisteredSlotsToFirebase();
    updateEnrollStatus(STATUS_IDLE, PREFIX_BIOMETRIC_ENROLLED + String(targetSlot));
  } else {
    updateEnrollStatus(STATUS_ERROR_STORAGE, ACTION_WRITE_ERR);
    alertUnauthorized();
    updateEnrollStatus(STATUS_IDLE, ACTION_WRITE_ERR);
  }

  currentEnrollStatus = STATUS_IDLE;
}

void deleteFingerprintSlot(int slotId) {
  if (slotId < 1 || slotId > MAX_FINGERPRINT_SLOTS) return;

  Serial.printf("Deleting Slot #%d...\n", slotId);
  bool success = false;

  if (WOKWI_SIMULATION_MODE) {
    simulatedSlots[slotId] = false;
    success = true;
  } else {
    if (finger.deleteModel(slotId) == FINGERPRINT_OK) success = true;
  }

  if (success) {
    Serial.printf("Slot #%d deleted successfully.\n", slotId);
    playBeep(BEEP_FREQ_HIGH, BEEP_DUR_SHORT);
    delay(SERIAL_FLUSH_DELAY_MS);
    playBeep(BEEP_FREQ_LOW, BEEP_DUR_MID);

    if (firebaseAuthenticated && Firebase.ready()) {
      Firebase.RTDB.deleteNode(&fbdo, LOCKER_PATH + PATH_REGISTERED_SLOTS + String(slotId));
      Firebase.RTDB.setInt(&fbdo, LOCKER_PATH + PATH_DELETE_SLOT, SLOT_CLEAR_TRIGGER);
      Firebase.RTDB.setString(&fbdo, LOCKER_PATH + PATH_LAST_ACTION, PREFIX_DELETED_SLOT + String(slotId));
    }
    syncRegisteredSlotsToFirebase();
  } else {
    if (firebaseAuthenticated && Firebase.ready()) {
      Firebase.RTDB.setInt(&fbdo, LOCKER_PATH + PATH_DELETE_SLOT, SLOT_ERROR_TRIGGER);
      Firebase.RTDB.setString(&fbdo, LOCKER_PATH + PATH_LAST_ACTION, PREFIX_DELETE_ERR_SLOT + String(slotId));
    }
  }
}

int getFingerprintID() {
  if (finger.getImage() != FINGERPRINT_OK) return FP_SEARCH_ERROR;
  if (finger.image2Tz() != FINGERPRINT_OK) return FP_SEARCH_ERROR;
  
  uint8_t p = finger.fingerFastSearch();
  if (p == FINGERPRINT_NOTFOUND) return FP_SEARCH_NOT_FOUND;
  if (p != FINGERPRINT_OK) return FP_SEARCH_ERROR;

  return finger.fingerID;
}

// ============================================================================
// 15. CLOUD & NETWORK COMMUNICATION
// ============================================================================
void connectWiFi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(BOOT_SERIAL_DELAY_MS);
  }
  Serial.println("\nWi-Fi Connected!");
}

void initFirebase() {
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Firebase Auth Successful");
    firebaseAuthenticated = true;
  } else {
    Serial.printf("Firebase Warning: %s\n", config.signer.signupError.message.c_str());
    firebaseAuthenticated = false;
  }

  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  if (firebaseAuthenticated) {
    if (Firebase.RTDB.beginStream(&streamData, LOCKER_PATH)) {
      Firebase.RTDB.setStreamCallback(&streamData, streamCallback, streamTimeoutCallback);
    }
  }
}

void streamCallback(FirebaseStream data) {
  String path = data.dataPath();

  if (path == PATH_IS_LOCKED && data.dataType() == "boolean") {
    applyLockState(data.boolData(), "[Remote App]", false);
  } else if (path == PATH_DELETE_SLOT && data.dataType() == "int") {
    if (data.intData() > 0) deleteFingerprintSlot(data.intData());
  } else if (path == PATH_ENROLL_STATUS && data.dataType() == "string") {
    if (data.stringData() == STATUS_START_ENROLL && currentEnrollStatus != STATUS_START_ENROLL) {
      currentEnrollStatus = STATUS_START_ENROLL;
    }
  } else if (path == PATH_ROOT && data.dataType() == "json") {
    FirebaseJson json = data.jsonObject();
    FirebaseJsonData result;

    if (json.get(result, "isLocked") && result.typeNum == FirebaseJson::JSON_BOOL) {
      applyLockState(result.boolValue, "[Remote App]", false);
    }
    if (json.get(result, "deleteSlot") && result.typeNum == FirebaseJson::JSON_INT) {
      if (result.intValue > 0) deleteFingerprintSlot(result.intValue);
    }
    if (json.get(result, "enrollStatus") && result.typeNum == FirebaseJson::JSON_STRING) {
      if (result.stringValue == STATUS_START_ENROLL && currentEnrollStatus != STATUS_START_ENROLL) {
        currentEnrollStatus = STATUS_START_ENROLL;
      }
    }
  }
}

void streamTimeoutCallback(bool timeout) {
  if (timeout) Serial.println("Firebase stream timeout, resuming...");
}

void updateEnrollStatus(String status, String lastAction) {
  if (firebaseAuthenticated && Firebase.ready()) {
    Firebase.RTDB.setString(&fbdo, LOCKER_PATH + PATH_ENROLL_STATUS, status);
    if (lastAction.length() > 0) {
      Firebase.RTDB.setString(&fbdo, LOCKER_PATH + PATH_LAST_ACTION, lastAction);
    }
  }
  Serial.println("Enroll Status -> " + status);
}

void syncRegisteredSlotsToFirebase() {
  if (!firebaseAuthenticated || !Firebase.ready()) return;

  FirebaseJsonArray arrayJson;
  if (WOKWI_SIMULATION_MODE) {
    for (int i = 1; i <= MAX_FINGERPRINT_SLOTS; i++) {
      if (simulatedSlots[i]) arrayJson.add(i);
    }
  } else {
    finger.getTemplateCount();
    for (int i = 1; i <= MAX_FINGERPRINT_SLOTS; i++) {
      if (finger.loadModel(i) == FINGERPRINT_OK) arrayJson.add(i);
    }
  }
  Firebase.RTDB.setArray(&fbdo, LOCKER_PATH + PATH_ACTIVE_SLOTS_LIST, &arrayJson);
}