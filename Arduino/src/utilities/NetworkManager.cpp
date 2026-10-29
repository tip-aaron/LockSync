#include "NetworkManager.hpp"
#include "constants/network.hpp"

NetworkManager *NetworkManager::_instance = nullptr;

void NetworkManager::timeSyncCallback(struct timeval *tv) {
  if (_instance) {
    _instance->_isTimeSynced = true;

    time_t now = tv->tv_sec;

    struct tm timeinfo;
    localtime_r(&now, &timeinfo);

    char timeStr[64];
    strftime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S", &timeinfo);
    Serial.printf(
        "[NTP EVENT] Time synchronized successfully! Current PST: %s\n",
        timeStr);
  }
}

void NetworkManager::begin() {
  _instance = this;
  WiFi.mode(WIFI_STA);

  WiFi.setAutoReconnect(true);

  WiFi.onEvent([this](WiFiEvent_t e, WiFiEventInfo_t i) { onWiFiStart(e, i); },
               ARDUINO_EVENT_WIFI_STA_START);

  WiFi.onEvent([this](WiFiEvent_t e, WiFiEventInfo_t i) { onWiFiGotIP(e, i); },
               ARDUINO_EVENT_WIFI_STA_GOT_IP);

  WiFi.onEvent(
      [this](WiFiEvent_t e, WiFiEventInfo_t i) { onWiFiDisconnected(e, i); },
      ARDUINO_EVENT_WIFI_STA_DISCONNECTED);

  sntp_set_time_sync_notification_cb(NetworkManager::timeSyncCallback);

  Serial.printf("[WIFI] Initiating background connection to '%s'...\n",
                constants::WIFI_SSID);

  WiFi.begin(constants::WIFI_SSID, constants::WIFI_PASSWORD);
}

void NetworkManager::onWiFiStart(WiFiEvent_t event, WiFiEventInfo_t info) {
  Serial.println(
      "[WIFI EVENT] Station interface started. Searching for access point...");
}

void NetworkManager::onWiFiGotIP(WiFiEvent_t event, WiFiEventInfo_t info) {
  _isConnected = true;
  Serial.printf("[WIFI EVENT] Connected! Assigned IP: %s\n",
                WiFi.localIP().toString().c_str());

  Serial.println("[NTP] Requesting time sync from servers...");
  configTime(constants::GMT_OFFSET_SEC, constants::DAYLIGHT_OFFSET_SEC,
             constants::NTP_SERVER_1, constants::NTP_SERVER_2,
             constants::NTP_SERVER_3);
}

void NetworkManager::onWiFiDisconnected(WiFiEvent_t event,
                                        WiFiEventInfo_t info) {
  _isConnected = false;
  _isTimeSynced = false;
  uint8_t reason = info.wifi_sta_disconnected.reason;

  Serial.printf("[WIFI EVENT] Disconnected! (Reason Code: %d). Retrying in "
                "background...\n",
                reason);
}

bool NetworkManager::isConnected() const { return _isConnected; }

bool NetworkManager::isTimeSynced() const { return _isTimeSynced; }