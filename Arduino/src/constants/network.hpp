#pragma once

#include <cstdint>

namespace constants {
constexpr const char *WIFI_SSID = "jerick";
constexpr const char *WIFI_PASSWORD = "kissmuna";
constexpr uint32_t WIFI_CONNECT_TIMEOUT_MS = 15000;
constexpr uint32_t WIFI_RECONNECT_INTERVAL_MS = 500;

constexpr const char *NTP_SERVER_1 = "ph.pool.ntp.org";
constexpr const char *NTP_SERVER_2 = "time.nist.gov";
constexpr const char *NTP_SERVER_3 = "time.google.com";

// GMT+8 (Philippines: 8 hours * 3600s)
constexpr long GMT_OFFSET_SEC = 28800;
// No Daylight Saving Time in the Philippines
constexpr int DAYLIGHT_OFFSET_SEC = 0;
constexpr uint32_t NTP_TIMEOUT_MS = 10000;
constexpr uint32_t NTP_RETRY_DELAY_MS = 250;

// Minimum valid Unix timestamp threshold (October 1, 2026 00:00:00 UTC) to
// confirm clock sync
constexpr long MIN_VALID_TIMESTAMP = 1790812800;
} // namespace constants
