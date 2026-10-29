#include "constants/common.hpp"
#include "constants/peripherals.hpp"
#include "constants/state.hpp"
#include "firebase/FirebaseManager.hpp"
#include "firebase/command_handlers.hpp"
#include "peripherals/Buzzer/Buzzer.hpp"
#include "peripherals/CloseButton/CloseButton.hpp"
#include "peripherals/FingerprintSensor/FingerprintSensor.hpp"
#include "utilities/NetworkManager.hpp"
#include "utilities/loop_handlers.hpp"
#include "utilities/memory_watcher.hpp"

CloseButton closeButton(constants::BUTTON_PIN, constants::BUTTON_DEBOUNCE_MS,
                        constants::BUTTON_ACTIVE_LOW);
LockServo lockServo(constants::SERVO_PIN, constants::SERVO_LOCKED_ANGLE,
                    constants::SERVO_UNLOCKED_ANGLE);
FingerprintSensor fingerprintSensor(Serial2, constants::FINGERPRINT_RX_PIN,
                                    constants::FINGERPRINT_TX_PIN);
Buzzer buzzer(constants::BUZZER_PIN, constants::BUZZER_CHANNEL);
NetworkManager netManager;
FirebaseManager fbManager;

void setup() {
  Serial.begin(constants::SERIAL_BAUD);

  closeButton.begin();
  netManager.begin();
  lockServo.begin(locker_state::isLocked);
  fingerprintSensor.begin();
  buzzer.begin();

  command_handlers::init(fbManager, netManager, lockServo, fingerprintSensor,
                         buzzer);
  loop_handlers::init(closeButton, lockServo, fingerprintSensor, netManager,
                      fbManager, buzzer);

  fbManager.begin(command_handlers::handleLockCommand,
                  command_handlers::handleEnrollCommand,
                  command_handlers::handleDeleteCommand,
                  command_handlers::handleCancelEnrollCommand,
                  command_handlers::handleResetUnauthorizedCommand);
}

void loop() {
  lockServo.tick();
  loop_handlers::processHardwareInputs();

  bool isOnline = netManager.isConnected() && netManager.isTimeSynced();

  fbManager.tick(isOnline, locker_state::isLocked,
                 locker_state::unauthorizedCount,
                 locker_state::enrollmentStatus);
  command_handlers::tick();

  // Trigger one-time startup sync as soon as Firebase is online
  if (isOnline) {
    fbManager.syncFingerprints(fingerprintSensor, buzzer);
  }

  utilities::printMemoryUsageTimed(5000);
  delay(constants::LOOP_DELAY_MS);
}