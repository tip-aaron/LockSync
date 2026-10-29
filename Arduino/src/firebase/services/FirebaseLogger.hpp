#pragma once

#include "constants/firebase.hpp"
#include <Arduino.h>
#include <cstddef>

using std::nullptr_t;

#include <Firebase_ESP_Client.h>
#include <cstddef>

/**
 * @brief Handles audit logging and unauthorized access tracking.
 *
 * Implements an offline-first strategy: when the network is unavailable or a
 * real-time database push fails, events are buffered into a static circular
 * ring buffer. Buffered logs are flushed automatically when connection is
 * restored.
 */
class FirebaseLogger {
public:
  /**
   * @brief Logs a named system event with a Unix timestamp to Firebase.
   *
   * @param reqData Dedicated HTTP/SSL request container.
   * @param eventType String identifier for the event (e.g.,
   * "PHYSICAL_BUTTON_LOCKED").
   * @param isNetworkAvailable Current network connection flag.
   *
   * @return true  Event was immediately and successfully written to Firebase
   * RTDB.
   * @return false Network was offline or the cloud write failed. The event was
   *               buffered locally into the offline queue for deferred
   * delivery.
   */
  bool logEvent(FirebaseData &reqData, const char *eventType,
                bool isNetworkAvailable);
  /**
   * @brief Sequentially pushes queued offline logs to Firebase until the queue
   * is empty or an outbound write fails due to connection drop.
   *
   * @param reqData Dedicated HTTP/SSL request container.
   * @param isNetworkAvailable Current network connection flag.
   */
  void flushPendingLogs(FirebaseData &reqData, bool isNetworkAvailable);

  /**
   * @brief Returns the total number of events currently held in the offline
   * queue.
   *
   * @return size_t Count ranging from 0 to constants::MAX_PENDING_LOGS.
   */
  size_t getQueueCount() const { return _queueCount; }

private:
  struct PendingLog {
    char eventType[constants::MAX_LOG_EVENT_LEN];
    time_t timestamp;
  };

  // Fixed-size circular buffer allocated on the stack/heap to prevent dynamic
  // RAM fragmentation
  PendingLog _logQueue[constants::MAX_PENDING_LOGS];
  size_t _queueHead = 0;  // Index of the oldest log awaiting push
  size_t _queueTail = 0;  // Index where the next offline log will be written
  size_t _queueCount = 0; // Number of active un-flushed items in the queue

  /**
   * @brief Inserts a log into the circular buffer. If the buffer is full,
   *        it overwrites the oldest un-flushed entry (FIFO eviction) to prevent
   * stack overflow.
   */
  void enqueueLog(const char *eventType, time_t timestamp);
};