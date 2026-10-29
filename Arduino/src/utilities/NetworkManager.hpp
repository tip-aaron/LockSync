#pragma once
#include <Arduino.h>
#include <WiFi.h>
#include <esp_sntp.h>

class NetworkManager {
public:
    void begin();
    bool isConnected() const;
    bool isTimeSynced() const;

private:
    bool _isConnected = false;
    bool _isTimeSynced = false;

    // WiFi Event Handlers
    void onWiFiStart(WiFiEvent_t event, WiFiEventInfo_t info);
    void onWiFiGotIP(WiFiEvent_t event, WiFiEventInfo_t info);
    void onWiFiDisconnected(WiFiEvent_t event, WiFiEventInfo_t info);

    // Static callback triggered directly by ESP-IDF SNTP engine when clock syncs
    static void timeSyncCallback(struct timeval *tv);
    
    // Singleton instance pointer for C-style SNTP callback bridge
    static NetworkManager* _instance;
};