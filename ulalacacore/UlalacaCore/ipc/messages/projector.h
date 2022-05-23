#ifndef ULALACA_CORE_IPC_MESSAGES_PROJECTOR_H
#define ULALACA_CORE_IPC_MESSAGES_PROJECTOR_H

#include <stdint.h>

#include "_global.h"


static const uint16_t IN_SCREEN_UPDATE_EVENT = 0x0101;
static const uint16_t IN_SCREEN_COMMIT_UPDATE = 0x0102;

static const uint16_t OUT_SCREEN_UPDATE_REQUEST = 0x0201;

static const uint16_t OUT_KEYBOARD_EVENT = 0x0311;

static const uint16_t OUT_MOUSE_MOVE_EVENT = 0x0321;
static const uint16_t OUT_MOUSE_BUTTON_EVENT = 0x0322;
static const uint16_t OUT_MOUSE_WHEEL_EVENT = 0x0323;


struct ProjectorMessageHeader {
    uint16_t messageType;

    uint64_t id;
    uint64_t replyTo;

    uint64_t timestamp;

    uint64_t length;
} FIXME_MARK_AS_PACKED_STRUCT;

/**
 * incoming message
 */
struct ScreenUpdateEvent {
    uint8_t type;

    struct Rect rect;
} FIXME_MARK_AS_PACKED_STRUCT;

struct ScreenCommitUpdate {
    struct Rect screenRect;
    uint64_t bitmapLength;
} FIXME_MARK_AS_PACKED_STRUCT;

static const uint8_t UPDATE_REQUEST_TYPE_ENTIRE_SCREEN = 0;
static const uint8_t UPDATE_REQUEST_TYPE_PARTIAL = 1;

struct ScreenUpdateRequest {
    uint8_t type;

    struct Rect rect;
};


static const uint16_t FLAG_IGNORE_TIMESTAMP_QUEUE = 0b00000001;
static const uint16_t FLAG_EMIT_EVENT_USING_KARABINER = 0b00010000;

static const uint8_t KEY_EVENT_TYPE_NOOP = 0;
static const uint8_t KEY_EVENT_TYPE_KEYUP = 1;
static const uint8_t KEY_EVENT_TYPE_KEYDOWN = 2;

/**
 * force release pressed keys
 */
static const uint8_t KEY_EVENT_TYPE_RESET = 4;

struct KeyboardEvent {
    uint8_t type;
    uint32_t keyCode;

    uint16_t flags;
} FIXME_MARK_AS_PACKED_STRUCT;



struct MouseMoveEvent {
    uint16_t x;
    uint16_t y;

    uint16_t flags;
} FIXME_MARK_AS_PACKED_STRUCT;


static const uint8_t MOUSE_EVENT_TYPE_NOOP = 0;
static const uint8_t MOUSE_EVENT_TYPE_MOUSEUP = 1;
static const uint8_t MOUSE_EVENT_TYPE_MOUSEDOWN = 2;

static const uint8_t MOUSE_EVENT_BUTTON_LEFT = 0;
static const uint8_t MOUSE_EVENT_BUTTON_RIGHT = 1;
static const uint8_t MOUSE_EVENT_BUTTON_MIDDLE = 2;

struct MouseButtonEvent {
    uint8_t type;
    uint8_t button;

    uint16_t flags;
} FIXME_MARK_AS_PACKED_STRUCT;

struct MouseWheelEvent {
    int32_t deltaX;
    int32_t deltaY;

    uint16_t flags;
} FIXME_MARK_AS_PACKED_STRUCT;


#endif