#ifndef ULALACA_CORE_IPC_MESSAGES_BROKER_H
#define ULALACA_CORE_IPC_MESSAGES_BROKER_H

#include <stdint.h>

#include "_global.h"

static const uint16_t RESPONSE_SESSION_READY = 0xA100;
static const uint16_t RESPONSE_REJECTION = 0xA101;
static const uint16_t REQUEST_SESSION = 0xA011;

struct BrokerMessageHeader {
    uint32_t version;

    uint16_t messageType;
    uint64_t timestamp;

    uint64_t length;
} FIXME_MARK_AS_PACKED_STRUCT;

static const uint8_t REJECT_REASON_INTERNAL_ERROR = 0;
static const uint8_t REJECT_REASON_AUTHENTICATION_FAILED = 1;
static const uint8_t REJECT_REASON_SESSION_NOT_AVAILABLE = 2;
static const uint8_t REJECT_REASON_INCOMPATIBLE_VERSION = 3;

/**
 * incoming message
 */
struct SessionReady {
    uint64_t sessionId;
    uint8_t isLoginSession;

    char path[1024];
} FIXME_MARK_AS_PACKED_STRUCT;

struct RequestRejection {
    uint8_t reason;
} FIXME_MARK_AS_PACKED_STRUCT;

struct RequestSession {
    char username[64];
    char password[256];
} FIXME_MARK_AS_PACKED_STRUCT;

#endif