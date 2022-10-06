#ifndef ULALACA_CORE_IPC_MESSAGES_PRIVATE_H
#define ULALACA_CORE_IPC_MESSAGES_PRIVATE_H

#include <stdint.h>
#include <unistd.h>

#include "_global.h"


/* constants: message type (broker -> projector) */
static const uint16_t TYPE_ACK = 0xa101;
static const uint16_t TYPE_NAK = 0xa102;

static const uint16_t TYPE_CONTROL = 0xa111;

/* constants: message type (projector -> broker) */
static const uint16_t TYPE_ANNOUNCEMENT = 0xa201;

/* constants: control message (projector -> broker) */
static const uint8_t CONTROL_TYPE_STOP_PROJECTOR = 1;
static const uint8_t CONTROL_TYPE_CREATE_LOGIN_SESSION = 2;

static const uint8_t CONTROL_FLAG_NO_FLAGS = 0;

/* constants: session announce */
static const uint8_t ANNOUNCEMENT_TYPE_SESSION_CREATED = 1;
static const uint8_t ANNOUNCEMENT_TYPE_SESSION_WILL_BE_DESTROYED = 2;

static const uint8_t ANNOUNCEMENT_FLAG_NO_FLAGS = 0;
static const uint8_t ANNOUNCEMENT_FLAG_IS_CONSOLE_SESSION = 1;
static const uint8_t ANNOUNCEMENT_FLAG_IS_LOGIN_SESSION = 2;
static const uint8_t ANNOUNCEMENT_FLAG_IS_BUSY = 3;

struct ULIPCPrivateACK {
    uint8_t flags;
} MARK_AS_PACKED_STRUCT;

struct ULIPCPrivateNAK {
    uint8_t flags;
} MARK_AS_PACKED_STRUCT;

struct ULIPCPrivateControl {
    uint8_t type;
    uint8_t flags;
} MARK_AS_PACKED_STRUCT;

struct ULIPCPrivateAnnouncement {
    uint8_t type;
    pid_t pid;
    char username[64];
    char endpoint[1024];
    uint8_t flags;
} MARK_AS_PACKED_STRUCT;

#endif
