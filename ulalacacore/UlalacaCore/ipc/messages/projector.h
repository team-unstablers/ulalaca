#ifndef ULALACA_CORE_IPC_MESSAGES_PROJECTOR_H
#define ULALACA_CORE_IPC_MESSAGES_PROJECTOR_H

#include <stdint.h>

#include "_global.h"


/* constants: message type (server -> client) */
static const uint16_t TYPE_SCREEN_UPDATE_NOTIFY = 0x0101;
static const uint16_t TYPE_SCREEN_UPDATE_COMMIT = 0x0102;

/* constants: message type (client -> server) */
static const uint16_t TYPE_EVENT_INVALIDATION = 0x0201;
static const uint16_t TYPE_EVENT_KEYBOARD     = 0x0311;
static const uint16_t TYPE_EVENT_MOUSE_MOVE   = 0x0321;
static const uint16_t TYPE_EVENT_MOUSE_BUTTON = 0x0322;
static const uint16_t TYPE_EVENT_MOUSE_WHEEL  = 0x0323;

/* constants: Screen update notification */
static const uint8_t SCREEN_UPDATE_NOTIFY_TYPE_ENTIRE_SCREEN = 0;
static const uint8_t SCREEN_UPDATE_NOTIFY_TYPE_PARTIAL = 1;

/* constants: Event Flags */
/** Ignores time-ordered queue. (event will be emitted immediately) */
static const uint16_t EVENT_IGNORE_TIMESTAMP_QUEUE = 0b00000001;


/* constants: Invalidation Event Types */
static const uint8_t INVALIDATION_EVENT_TYPE_ENTIRE_SCREEN = 0;
static const uint8_t INVALIDATION_EVENT_TYPE_PARTIAL = 1;

/* constants: Keyboard Event Types */
static const uint8_t KEYBOARD_EVENT_TYPE_NOOP = 0;
static const uint8_t KEYBOARD_EVENT_TYPE_KEYUP = 1;
static const uint8_t KEYBOARD_EVENT_TYPE_KEYDOWN = 2;
/** force release all pressed keys. */
static const uint8_t KEY_EVENT_TYPE_RESET = 4;


/* constants: Mouse Button Event */
static const uint8_t MOUSE_EVENT_TYPE_NOOP = 0;
static const uint8_t MOUSE_EVENT_TYPE_UP = 1;
static const uint8_t MOUSE_EVENT_TYPE_DOWN = 2;

static const uint8_t MOUSE_EVENT_BUTTON_LEFT = 0;
static const uint8_t MOUSE_EVENT_BUTTON_RIGHT = 1;
static const uint8_t MOUSE_EVENT_BUTTON_MIDDLE = 2;

/* message definition: server -> client */
struct ULIPCScreenUpdateNotify {
    uint8_t type;
    struct ULIPCRect rect;
} MARK_AS_PACKED_STRUCT;

struct ULIPCScreenUpdateCommit {
    struct ULIPCRect screenRect;
    uint64_t bitmapLength;
} MARK_AS_PACKED_STRUCT;


/* message definition: client -> server */
struct ULIPCInvalidationEvent {
    uint8_t type;
    struct ULIPCRect rect;
};

struct ULIPCKeyboardEvent {
    uint8_t type;
    uint32_t keyCode;

    uint16_t flags;
} MARK_AS_PACKED_STRUCT;

struct ULIPCMouseMoveEvent {
    uint16_t x;
    uint16_t y;

    uint16_t flags;
} MARK_AS_PACKED_STRUCT;

struct ULIPCMouseButtonEvent {
    uint8_t type;
    uint8_t button;

    uint16_t flags;
} MARK_AS_PACKED_STRUCT;

struct ULIPCMouseWheelEvent {
    int32_t deltaX;
    int32_t deltaY;

    uint16_t flags;
} MARK_AS_PACKED_STRUCT;



#endif