#ifndef ULALACA_CORE_IPC_MESSAGES_BROKER_H
#define ULALACA_CORE_IPC_MESSAGES_BROKER_H

#include <stdint.h>

#include "_global.h"

/* constants: message type (server -> client) */
static const uint16_t TYPE_SESSION_REQUEST_RESOLVED = 0xA100;
static const uint16_t TYPE_SESSION_REQUEST_REJECTED = 0xA101;

/* constants: message type (client -> server) */
static const uint16_t TYPE_SESSION_REQUEST = 0xA011;


/* constants: reject reason */
static const uint8_t REJECT_REASON_INTERNAL_ERROR = 0;
static const uint8_t REJECT_REASON_AUTHENTICATION_FAILED = 1;
static const uint8_t REJECT_REASON_SESSION_NOT_AVAILABLE = 2;
static const uint8_t REJECT_REASON_INCOMPATIBLE_VERSION = 3;


/* message definition: server -> client */
struct ULIPCSessionRequestResolved {
    uint64_t sessionId;
    uint8_t isLoginSession;

    char path[1024];
} FIXME_MARK_AS_PACKED_STRUCT;

struct ULIPCSessionRequestRejected {
    uint8_t reason;
} FIXME_MARK_AS_PACKED_STRUCT;

/* message definition: client -> server */
struct ULIPCSessionRequest {
    char username[64];
    char password[256];
} FIXME_MARK_AS_PACKED_STRUCT;

#endif