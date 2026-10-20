#include <Adafruit_Fingerprint.h>
#include <Arduino.h>
#include <Firebase_ESP_Client.h>
#include <HardwareSerial.h>
#include <WiFi.h>

#include <addons/RTDBHelper.h>
#include <addons/TokenHelper.h>

// ============================================================================
// 1. NETWORK & CLOUD CREDENTIALS
// ============================================================================
#define WIFI_SSID "Wokwi-GUEST"
#define WIFI_PASSWORD ""
#define API_KEY "AIzaSyCwXNa8Ki40gn8W3_QdC6dbiIRkJsILGxA"
#define DATABASE_URL                                                           \
  "https://locksync-ab6fa-default-rtdb.asia-southeast1.firebasedatabase.app"

#define LOCKER_ID "locker_01"
const String LOCKER_PATH = "/lockers/" + String(LOCKER_ID);

const char *NTP_SERVER_1 = "pool.ntp.org";
const char *NTP_SERVER_2 = "time.nist.gov";

// ============================================================================
// 2. HARDWARE PIN DEFINITIONS
// ============================================================================
#define PIR_PIN 14
#define SERVO_PIN 13
#define BUZZER_PIN 25
#define LED_PIN 26
#define BUTTON_PIN 27
#define FP_RX_PIN 16
#define FP_TX_PIN 17

// ============================================================================
// 3. HARDWARE SPECIFICATIONS & TIMING CONSTANTS
// ============================================================================
constexpr unsigned long SERIAL_BAUD = 115200;
constexpr unsigned long FP_SERIAL_BAUD = 57600;

constexpr int SERVO_FREQ_HZ = 50;
constexpr int SERVO_RESOLUTION_BITS = 16;
constexpr int SERVO_MIN_PULSE_US = 500;
constexpr int SERVO_MAX_PULSE_US = 2400;
constexpr uint32_t SERVO_PERIOD_US = 20000;
constexpr uint32_t SERVO_MAX_DUTY = 65535;
constexpr int SERVO_MAX_ANGLE = 180;

constexpr int LOCKED_POS = 0;
constexpr int UNLOCKED_POS = 90;

constexpr unsigned long BUTTON_DEBOUNCE_MS = 50;
constexpr unsigned long ENROLL_TIMEOUT_MS = 25000;
constexpr unsigned long BOOT_STABILIZE_MS = 3000;
constexpr unsigned long LOOP_DELAY_MS = 50;
constexpr unsigned long SERIAL_FLUSH_DELAY_MS = 50;
constexpr unsigned long BOOT_SERIAL_DELAY_MS = 500;

constexpr int MAX_FINGERPRINT_SLOTS = 162;
constexpr int SLOT_ARRAY_SIZE = MAX_FINGERPRINT_SLOTS + 1;
constexpr int SLOT_INVALID = -1;

constexpr int FP_SEARCH_NOT_FOUND = -2;
constexpr int FP_SEARCH_ERROR = -1;

#define WOKWI_SIMULATION_MODE true

// ============================================================================
// 4. BUZZER FREQUENCIES & DURATIONS
// ============================================================================
constexpr int BEEP_FREQ_ALERT = 400;
constexpr int BEEP_FREQ_LOW = 800;
constexpr int BEEP_FREQ_MID = 1000;
constexpr int BEEP_FREQ_HIGH = 1200;
constexpr int BEEP_FREQ_SUCCESS = 1500;
constexpr int BEEP_FREQ_COMPLETE = 2000;

constexpr int BEEP_DUR_SHORT = 100;
constexpr int BEEP_DUR_MID = 150;
constexpr int BEEP_DUR_LONG = 200;
constexpr int BEEP_DUR_ALERT = 200;

// ============================================================================
// 5. SERIAL MONITOR COMMAND CHARACTERS
// ============================================================================
constexpr char CMD_SIM_VALID_SCAN = '1';
constexpr char CMD_SIM_INVALID_SCAN = '2';
constexpr char CMD_SIM_ENROLL = 'e';
constexpr char CMD_SIM_DELETE = 'd';

// ============================================================================
// 6. FIREBASE DATABASE PATHS & STATUS STRINGS
// ============================================================================
const String PATH_IS_LOCKED = "/isLocked";
const String PATH_ENROLL_STATUS = "/enrollStatus";
const String PATH_ENROLL_LABEL = "/enrollLabel";
const String PATH_MOTION_DETECTED = "/motionDetected";
const String PATH_LAST_ACTION = "/lastAction";
const String PATH_TAMPER_ALERT = "/unauthorizedAttempt";
const String PATH_REGISTERED_SLOTS = "/registeredSlots";
const String PATH_REGISTERED_SLOT_PREFIX = "/registeredSlots/slot_";
const String PATH_HISTORY = "/history";
const String PATH_ROOT = "/";

const String STATUS_IDLE = "IDLE";
const String STATUS_START_ENROLL = "START_ENROLL";
const String STATUS_PLACE_FINGER_1 = "PLACE_FINGER_1";
const String STATUS_PLACE_FINGER_2 = "PLACE_FINGER_2";
const String STATUS_REMOVE_FINGER = "REMOVE_FINGER";
const String STATUS_PROCESSING = "PROCESSING";
const String STATUS_COMPLETED = "COMPLETED";
const String STATUS_TIMEOUT = "TIMEOUT";
const String STATUS_CANCELED = "CANCELED";
const String STATUS_ERROR_STORAGE = "ERROR_STORAGE_FAILED";
const String STATUS_ERROR_MATCH = "ERROR_PRINTS_DONT_MATCH";
const String STATUS_ERROR_SCAN = "ERROR_SCAN_FAILED";

const String ACTION_LOCK = "LOCK";
const String ACTION_UNLOCK = "UNLOCK";
const String ACTION_REMOTE_LOCK = "REMOTE_LOCK";
const String ACTION_REMOTE_UNLOCK = "REMOTE_UNLOCK";
const String ACTION_ENROLLMENT = "ENROLLMENT";
const String ACTION_SLOT_DELETED = "SLOT_DELETED";
const String ACTION_MOTION_DETECTED = "MOTION_DETECTED";
const String ACTION_UNAUTHORIZED = "UNAUTHORIZED_ATTEMPT";

const String PREFIX_MATCH_FINGER = "MATCH_FINGER_ID_";
const String LABEL_FINGERPRINT_PREFIX = "Fingerprint ";

// ============================================================================
// 7. GLOBAL OBJECTS & STATE
// ============================================================================
HardwareSerial fpSerial(2);
Adafruit_Fingerprint finger(&fpSerial);

FirebaseData streamData, fbdo;
FirebaseAuth auth;
FirebaseConfig config;

bool isLocked = true;
bool lastMotionState = false;
bool lastRawButtonState = HIGH;
bool lastStableButtonState = HIGH;
unsigned long lastButtonDebounceMs = 0;
bool firebaseAuthenticated = false;
String currentEnrollStatus = STATUS_IDLE;
unsigned long bootTimeMs = 0;
bool isTamperAlertActive = false;
unsigned long lastTamperBeepMs = 0;
bool tamperBuzzerState = false;
String enrollLabel = LABEL_FINGERPRINT_PREFIX + String(1);

bool simulatedSlots[SLOT_ARRAY_SIZE] = {false};

// ============================================================================
// 8. FUNCTION DECLARATIONS
// ============================================================================
void initServoHardware();
void handleSerialCommands();
void handleTamperAlarm();
void logHistory(String action, String description, String enrollStatus = "",
                int slotID = -1);
void setServoAngle(int angle);
void playBeep(int freq, int durationMs);
void flushSerialBuffer();
void handlePIRSensor();
void handleLockButton();
void handleBiometricWorkflow();

void applyLockState(bool targetLocked, String source, bool updateCloud);
void alertUnauthorized();

uint8_t waitForFingerScan();
bool waitWithCancelCheck(unsigned long durationMs);
int getNextFreeSlot();
void processAppEnrollment();
void reconcileRegisteredSlots(FirebaseJson &slotsJson);
void purgeSingleSlot(int slotId);
int getFingerprintID();

void connectWiFi();
void initFirebase();
void syncInitialState();
void streamCallback(FirebaseStream data);
void streamTimeoutCallback(bool timeout);
void updateEnrollStatus(String status, String lastAction = "");

// ============================================================================
// 9. HARDWARE DRIVERS & UTILITIES
// ============================================================================
void initNTPTime() {
  configTime(0, 0, NTP_SERVER_1, NTP_SERVER_2);
  Serial.print("Synchronizing NTP time");
  time_t now = time(nullptr);
  unsigned long startWait = millis();
  while (now < 100000 && (millis() - startWait < 5000)) {
    delay(200);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println("\nTime sync complete.");
}

uint64_t getEpochMs() {
  struct timeval tv;
  gettimeofday(&tv, NULL);
  return ((uint64_t)tv.tv_sec * 1000ULL) + (tv.tv_usec / 1000ULL);
}

void logHistory(String action, String description, String enrollStatus,
                int slotID) {
  if (!firebaseAuthenticated || !Firebase.ready())
    return;

  FirebaseJson historyJson;
  historyJson.add("action", action);
  historyJson.add("description", description);
  historyJson.add("timestamp", getEpochMs());

  if (enrollStatus.length() > 0) {
    historyJson.add("enrollStatus", enrollStatus);
  }
  if (slotID > 0) {
    historyJson.add("slotID", slotID);
  }

  Firebase.RTDB.pushJSON(&fbdo, LOCKER_PATH + PATH_HISTORY, &historyJson);
}

void initServoHardware() {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcAttach(SERVO_PIN, SERVO_FREQ_HZ, SERVO_RESOLUTION_BITS);
#else
  ledcSetup(0, SERVO_FREQ_HZ, SERVO_RESOLUTION_BITS);
  ledcAttachPin(SERVO_PIN, 0);
#endif
}

void setServoAngle(int angle) {
  int pulseWidthUs =
      map(angle, 0, SERVO_MAX_ANGLE, SERVO_MIN_PULSE_US, SERVO_MAX_PULSE_US);
  uint32_t duty = (pulseWidthUs * SERVO_MAX_DUTY) / SERVO_PERIOD_US;
#if defined(ESP_ARDUINO_VERSION_MAJOR) && ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(SERVO_PIN, duty);
#else
  ledcWrite(0, duty);
#endif
}

void playBeep(int freq, int durationMs) {
  if (freq <= 0)
    return;
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
    Serial.println(
        "Notice: Fingerprint sensor running in Wokwi Simulation Mode.");
  }

  connectWiFi();
  initNTPTime();
  initFirebase();
  syncInitialState();

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
  handleTamperAlarm();
  delay(LOOP_DELAY_MS);
}

void handleTamperAlarm() {
  if (!isTamperAlertActive)
    return;

  unsigned long currentMs = millis();
  if (currentMs - lastTamperBeepMs >= 150) {
    lastTamperBeepMs = currentMs;
    tamperBuzzerState = !tamperBuzzerState;

    if (tamperBuzzerState) {
      playBeep(BEEP_FREQ_ALERT, 80);
    } else {
      digitalWrite(BUZZER_PIN, LOW);
    }
  }
}

// ============================================================================
// 12. UNIFIED HARDWARE CONTROL & SECURITY ACTIONS
// ============================================================================
void applyLockState(bool targetLocked, String source, bool updateCloud) {
  if (targetLocked == isLocked)
    return;

  isLocked = targetLocked;

  String actionType = isLocked ? ACTION_LOCK : ACTION_UNLOCK;
  if (source == "[Remote App]") {
    actionType = isLocked ? ACTION_REMOTE_LOCK : ACTION_REMOTE_UNLOCK;
  }

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
    if (source != "[Remote App]") {
      logHistory(actionType, "Locker state changed via " + source);
    }

    updateJson.add("isLocked", isLocked);
    updateJson.add("lastAction", source);
    Firebase.RTDB.updateNode(&fbdo, LOCKER_PATH, &updateJson);
  }
}

void alertUnauthorized() {
  Serial.println("Access Denied - Unauthorized Attempt!");
  isTamperAlertActive = true;

  if (firebaseAuthenticated && Firebase.ready()) {
    logHistory(ACTION_UNAUTHORIZED, "Unauthorized access attempt detected");
    Firebase.RTDB.setString(&fbdo, LOCKER_PATH + PATH_LAST_ACTION,
                            ACTION_UNAUTHORIZED);
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
      applyLockState(false, "SIMULATION", true);
    } else if (cmd == CMD_SIM_INVALID_SCAN) {
      Serial.println("[Simulated] Fingerprint mismatch!");
      alertUnauthorized();
    } else if (cmd == CMD_SIM_ENROLL) {
      Serial.println("[Simulated] Initiating enrollment...");
      currentEnrollStatus = STATUS_START_ENROLL;
    }
  }
}

void handlePIRSensor() {
  if (millis() - bootTimeMs <= BOOT_STABILIZE_MS)
    return;

  bool currentMotion = digitalRead(PIR_PIN) == HIGH;
  if (currentMotion && !lastMotionState) {
    Serial.println("PIR: Motion detected near locker!");
    if (firebaseAuthenticated && Firebase.ready()) {
      logHistory(ACTION_MOTION_DETECTED, "Motion detected near locker sensor");
      Firebase.RTDB.setBool(&fbdo, LOCKER_PATH + PATH_MOTION_DETECTED, true);
      Firebase.RTDB.setString(&fbdo, LOCKER_PATH + PATH_LAST_ACTION,
                              ACTION_MOTION_DETECTED);
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
        applyLockState(true, "LOCK_BUTTON", true);
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
// 14. BIOMETRIC ENROLLMENT & RECONCILIATION LOGIC
// ============================================================================
uint8_t waitForFingerScan() {
  flushSerialBuffer();
  unsigned long start = millis();

  while (millis() - start < ENROLL_TIMEOUT_MS) {
    if (currentEnrollStatus == STATUS_CANCELED ||
        currentEnrollStatus == STATUS_IDLE) {
      Serial.println("Fingerprint scanning cancelled!");
      return FINGERPRINT_TIMEOUT;
    }

    if (!WOKWI_SIMULATION_MODE) {
      if (finger.getImage() == FINGERPRINT_OK)
        return FINGERPRINT_OK;
    } else if (Serial.available() > 0) {
      if (Serial.read() == CMD_SIM_VALID_SCAN) {
        flushSerialBuffer();
        return FINGERPRINT_OK;
      }
    }
    delay(LOOP_DELAY_MS);
  }
  return FINGERPRINT_TIMEOUT;
}

bool waitWithCancelCheck(unsigned long durationMs) {
  unsigned long start = millis();
  while (millis() - start < durationMs) {
    if (currentEnrollStatus == STATUS_CANCELED ||
        currentEnrollStatus == STATUS_IDLE) {
      return false;
    }
    delay(LOOP_DELAY_MS);
  }
  return (currentEnrollStatus != STATUS_CANCELED &&
          currentEnrollStatus != STATUS_IDLE);
}

int getNextFreeSlot() {
  if (WOKWI_SIMULATION_MODE) {
    for (int slot = 1; slot <= MAX_FINGERPRINT_SLOTS; slot++) {
      if (!simulatedSlots[slot])
        return slot;
    }
    return SLOT_INVALID;
  }

  finger.getTemplateCount();
  for (int slot = 1; slot <= MAX_FINGERPRINT_SLOTS; slot++) {
    if (finger.loadModel(slot) != FINGERPRINT_OK)
      return slot;
  }
  return SLOT_INVALID;
}

void processAppEnrollment() {
  int targetSlot = getNextFreeSlot();
  if (targetSlot < 0) {
    Serial.println("Error: No available slots remaining!");
    updateEnrollStatus(STATUS_ERROR_STORAGE, ACTION_ENROLLMENT);
    return;
  }

  Serial.printf("Starting enrollment for target Slot #%d\n", targetSlot);

  // --- SCAN STEP 1 ---
  updateEnrollStatus(STATUS_PLACE_FINGER_1, ACTION_ENROLLMENT);
  playBeep(BEEP_FREQ_MID, BEEP_DUR_SHORT);

  if (waitForFingerScan() != FINGERPRINT_OK ||
      currentEnrollStatus == STATUS_CANCELED ||
      currentEnrollStatus == STATUS_IDLE) {
    Serial.println("Enrollment aborted during Scan 1.");
    currentEnrollStatus = STATUS_IDLE;
    return;
  }

  updateEnrollStatus(STATUS_REMOVE_FINGER, ACTION_ENROLLMENT);
  playBeep(BEEP_FREQ_HIGH, BEEP_DUR_SHORT);

  if (!waitWithCancelCheck(1500)) {
    Serial.println("Enrollment aborted during remove-finger delay.");
    currentEnrollStatus = STATUS_IDLE;
    return;
  }

  // --- SCAN STEP 2 ---
  updateEnrollStatus(STATUS_PLACE_FINGER_2, ACTION_ENROLLMENT);
  playBeep(BEEP_FREQ_MID, BEEP_DUR_SHORT);

  if (waitForFingerScan() != FINGERPRINT_OK ||
      currentEnrollStatus == STATUS_CANCELED ||
      currentEnrollStatus == STATUS_IDLE) {
    Serial.println("Enrollment aborted during Scan 2.");
    currentEnrollStatus = STATUS_IDLE;
    return;
  }

  updateEnrollStatus(STATUS_PROCESSING, ACTION_ENROLLMENT);

  // --- ATOMIC VERIFICATION BEFORE COMMITMENT ---
  if (firebaseAuthenticated && Firebase.ready()) {
    if (Firebase.RTDB.getString(&fbdo, LOCKER_PATH + PATH_ENROLL_STATUS)) {
      if (fbdo.dataType() == "string") {
        String cloudStatus = fbdo.stringData();
        if (cloudStatus == STATUS_CANCELED || cloudStatus == STATUS_IDLE) {
          Serial.println("Atomic Check: Remote cancellation detected! Aborting "
                         "commitment.");
          currentEnrollStatus = STATUS_IDLE;
          return;
        }
      }
    }
  }

  if (currentEnrollStatus == STATUS_CANCELED ||
      currentEnrollStatus == STATUS_IDLE) {
    Serial.println("Enrollment canceled right before hardware commit.");
    currentEnrollStatus = STATUS_IDLE;
    return;
  }

  // --- COMMITMENT ---
  int p =
      WOKWI_SIMULATION_MODE ? FINGERPRINT_OK : finger.storeModel(targetSlot);
  if (p == FINGERPRINT_OK) {
    if (WOKWI_SIMULATION_MODE)
      simulatedSlots[targetSlot] = true;

    Serial.printf("SUCCESS! Stored fingerprint in Slot #%d\n", targetSlot);

    if (firebaseAuthenticated && Firebase.ready()) {
      String slotNodePath =
          LOCKER_PATH + PATH_REGISTERED_SLOT_PREFIX + String(targetSlot);
      String targetLabel =
          (enrollLabel.length() > 0)
              ? enrollLabel
              : (LABEL_FINGERPRINT_PREFIX + String(targetSlot));

      Serial.printf("Applying label '%s' to Slot #%d\n", targetLabel.c_str(),
                    targetSlot);

      FirebaseJson slotJson;
      slotJson.add("slotId", targetSlot);
      slotJson.add("label", targetLabel);
      slotJson.add("registeredAt", getEpochMs());
      Firebase.RTDB.updateNode(&fbdo, slotNodePath, &slotJson);
    }

    playBeep(BEEP_FREQ_SUCCESS, BEEP_DUR_MID);
    delay(BEEP_DUR_MID);
    playBeep(BEEP_FREQ_COMPLETE, BEEP_DUR_LONG);

    updateEnrollStatus(STATUS_COMPLETED, ACTION_ENROLLMENT);
    updateEnrollStatus(STATUS_IDLE, ACTION_ENROLLMENT);
  } else {
    updateEnrollStatus(STATUS_ERROR_STORAGE, ACTION_ENROLLMENT);
    alertUnauthorized();
  }

  currentEnrollStatus = STATUS_IDLE;
}

void purgeSingleSlot(int slotId) {
  if (slotId < 1 || slotId > MAX_FINGERPRINT_SLOTS)
    return;

  bool existsLocally = WOKWI_SIMULATION_MODE
                           ? simulatedSlots[slotId]
                           : (finger.loadModel(slotId) == FINGERPRINT_OK);

  if (existsLocally) {
    Serial.printf(
        "[Purge Event] Deletion detected -> Purging Slot #%d from hardware\n",
        slotId);
    if (WOKWI_SIMULATION_MODE) {
      simulatedSlots[slotId] = false;
    } else {
      finger.deleteModel(slotId);
    }
    playBeep(BEEP_FREQ_LOW, BEEP_DUR_SHORT);
    Serial.printf("[Purge Event] Slot #%d purged successfully.\n", slotId);
  } else {
    Serial.printf("[Purge Event] Deletion requested for Slot #%d, but slot was "
                  "already empty.\n",
                  slotId);
  }
}

// Pure reconciliation against /registeredSlots (Single Source of Truth)
void reconcileRegisteredSlots(FirebaseJson &slotsJson) {
  bool activeInCloud[SLOT_ARRAY_SIZE] = {false};
  FirebaseJsonData result;

  for (int slot = 1; slot <= MAX_FINGERPRINT_SLOTS; slot++) {
    String key = "slot_" + String(slot);
    if (slotsJson.get(result, key) &&
        result.typeNum != FirebaseJson::JSON_NULL) {
      activeInCloud[slot] = true;
    }
  }

  for (int slot = 1; slot <= MAX_FINGERPRINT_SLOTS; slot++) {
    bool existsLocally = WOKWI_SIMULATION_MODE
                             ? simulatedSlots[slot]
                             : (finger.loadModel(slot) == FINGERPRINT_OK);

    if (existsLocally && !activeInCloud[slot]) {
      purgeSingleSlot(slot);
    }
  }
}

int getFingerprintID() {
  if (finger.getImage() != FINGERPRINT_OK)
    return FP_SEARCH_ERROR;
  if (finger.image2Tz() != FINGERPRINT_OK)
    return FP_SEARCH_ERROR;

  uint8_t p = finger.fingerFastSearch();
  if (p == FINGERPRINT_NOTFOUND)
    return FP_SEARCH_NOT_FOUND;
  if (p != FINGERPRINT_OK)
    return FP_SEARCH_ERROR;

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

  fbdo.setBSSLBufferSize(16384 /* Rx */, 1024 /* Tx */);
  streamData.setBSSLBufferSize(16384 /* Rx */, 1024 /* Tx */);

  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Firebase Auth Successful");
    firebaseAuthenticated = true;
  } else {
    Serial.printf("Firebase Warning: %s\n",
                  config.signer.signupError.message.c_str());
    firebaseAuthenticated = false;
  }

  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  if (firebaseAuthenticated) {
    if (Firebase.RTDB.beginStream(&streamData, LOCKER_PATH)) {
      Firebase.RTDB.setStreamCallback(&streamData, streamCallback,
                                      streamTimeoutCallback);
    }
  }
}

void syncInitialState() {
  if (!firebaseAuthenticated || !Firebase.ready())
    return;

  Serial.println("Syncing initial state with Firebase...");

  // 1. Reconcile Lock State
  if (Firebase.RTDB.getBool(&fbdo, LOCKER_PATH + PATH_IS_LOCKED)) {
    if (fbdo.dataType() == "boolean") {
      bool remoteLocked = fbdo.boolData();
      if (remoteLocked) {
        Serial.println(
            "Initial State: Remote isLocked is TRUE. Hardware locked.");
        setServoAngle(LOCKED_POS);
        digitalWrite(LED_PIN, LOW);
        isLocked = true;
      } else {
        Serial.println(
            "Initial State: Remote isLocked is FALSE. Hardware unlocked.");
        setServoAngle(UNLOCKED_POS);
        digitalWrite(LED_PIN, HIGH);
        isLocked = false;
      }
    }
  }

  // 2. Reconcile Active Enroll Label
  if (Firebase.RTDB.getString(&fbdo, LOCKER_PATH + PATH_ENROLL_LABEL)) {
    if (fbdo.dataType() == "string" && fbdo.stringData().length() > 0) {
      enrollLabel = fbdo.stringData();
      Serial.printf("Initial State: Remote enrollLabel fetched: '%s'\n",
                    enrollLabel.c_str());
    }
  }

  // 3. Reconcile Registered Hardware Slots
  if (Firebase.RTDB.getJSON(&fbdo, LOCKER_PATH + PATH_REGISTERED_SLOTS)) {
    if (fbdo.dataType() == "json") {
      FirebaseJson slotsJson = fbdo.jsonObject();
      reconcileRegisteredSlots(slotsJson);
    }
  } else {
    FirebaseJson emptyJson;
    reconcileRegisteredSlots(emptyJson);
  }
}

void streamCallback(FirebaseStream data) {
  String path = data.dataPath();

  if (path == PATH_IS_LOCKED && data.dataType() == "boolean") {
    applyLockState(data.boolData(), "[Remote App]", false);
  } else if (path == PATH_ENROLL_LABEL && data.dataType() == "string") {
    enrollLabel = data.stringData();
    Serial.printf("[Stream Event] Live enrollLabel update: '%s'\n",
                  enrollLabel.c_str());
  } else if (path == PATH_REGISTERED_SLOTS) {
    // 1. Root JSON payload update
    if (data.dataType() == "json") {
      Serial.println("[Stream Callback] Full /registeredSlots JSON map "
                     "received. Reconciling hardware...");
      FirebaseJson slotsJson = data.jsonObject();
      reconcileRegisteredSlots(slotsJson);
    } else if (data.dataType() == "null") {
      Serial.println("[Stream Deletion Event] Root /registeredSlots node "
                     "wiped. Purging all local slots...");
      for (int slot = 1; slot <= MAX_FINGERPRINT_SLOTS; slot++) {
        purgeSingleSlot(slot);
      }
    }
  } else if (path.startsWith(PATH_REGISTERED_SLOTS + "/")) {
    String subPath =
        path.substring(PATH_REGISTERED_SLOTS.length() + 1); // e.g. "slot_1"
    int slashIdx = subPath.indexOf('/');

    // Target direct child slot node modifications (e.g., /registeredSlots/slot_1)
    if (slashIdx == -1 && subPath.startsWith("slot_")) {
      int targetSlot = subPath.substring(5).toInt();
      if (targetSlot > 0) {
        if (data.dataType() == "null") {
          Serial.printf("[Stream Deletion Event] Slot #%d node removed in "
                        "cloud. Purging hardware...\n",
                        targetSlot);
          purgeSingleSlot(targetSlot);
        } else if (data.dataType() == "json") {
          Serial.printf("[Stream Event] Slot #%d stored/updated in cloud "
                        "successfully. No purge needed.\n",
                        targetSlot);
        }
      }
    }
  } else if (path == PATH_ENROLL_STATUS && data.dataType() == "string") {
    if (data.stringData() == STATUS_START_ENROLL &&
        currentEnrollStatus != STATUS_START_ENROLL) {
      currentEnrollStatus = STATUS_START_ENROLL;
    } else if (data.stringData() == STATUS_CANCELED ||
               data.stringData() == STATUS_IDLE) {
      currentEnrollStatus = STATUS_IDLE;
    }
  } else if (path == PATH_TAMPER_ALERT && data.dataType() == "boolean") {
    isTamperAlertActive = data.boolData();
  } else if (path == PATH_ROOT && data.dataType() == "json") {
    FirebaseJson json = data.jsonObject();
    FirebaseJsonData result;

    if (json.get(result, "isLocked") &&
        result.typeNum == FirebaseJson::JSON_BOOL) {
      applyLockState(result.boolValue, "[Remote App]", false);
    }

    if (json.get(result, "registeredSlots")) {
      if (result.typeNum == FirebaseJson::JSON_OBJECT) {
        Serial.println(
            "[Stream Root] registeredSlots object updated. Reconciling...");
        FirebaseJson slotsJson;
        result.getJSON(slotsJson);
        reconcileRegisteredSlots(slotsJson);
      } else if (result.typeNum == FirebaseJson::JSON_NULL) {
        Serial.println("[Stream Root Deletion] registeredSlots set to null. "
                       "Purging all local hardware slots...");
        for (int slot = 1; slot <= MAX_FINGERPRINT_SLOTS; slot++) {
          purgeSingleSlot(slot);
        }
      }
    }

    if (json.get(result, "enrollStatus") &&
        result.typeNum == FirebaseJson::JSON_STRING) {
      if (result.stringValue == STATUS_START_ENROLL &&
          currentEnrollStatus != STATUS_START_ENROLL) {
        currentEnrollStatus = STATUS_START_ENROLL;
      } else if (result.stringValue == STATUS_CANCELED ||
                 result.stringValue == STATUS_IDLE) {
        currentEnrollStatus = STATUS_IDLE;
      }
    }

    if (json.get(result, "enrollLabel") &&
        result.typeNum == FirebaseJson::JSON_STRING) {
      enrollLabel = result.stringValue;
    }

    if (json.get(result, "unauthorizedAttempt") &&
        result.typeNum == FirebaseJson::JSON_BOOL) {
      isTamperAlertActive = result.boolValue;
    }
  }
}

void streamTimeoutCallback(bool timeout) {
  if (timeout)
    Serial.println("Firebase stream timeout, resuming...");
}

void updateEnrollStatus(String status, String lastAction) {
  if (firebaseAuthenticated && Firebase.ready()) {
    Firebase.RTDB.setString(&fbdo, LOCKER_PATH + PATH_ENROLL_STATUS, status);
    if (lastAction.length() > 0) {
      Firebase.RTDB.setString(&fbdo, LOCKER_PATH + PATH_LAST_ACTION,
                              lastAction);
    }
  }
  Serial.println("Enroll Status -> " + status);
}