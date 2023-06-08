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

static const uint16_t TYPE_PROJECTION_START        = 0x0401;
static const uint16_t TYPE_PROJECTION_STOP         = 0x0402;
static const uint16_t TYPE_PROJECTION_HELLO        = 0x0411;

static const uint16_t TYPE_PROJECTION_SET_VIEWPORT = 0x0421;

/* constants: message type (client <-> server) */
static const uint16_t TYPE_STREAM_DATA    = 0x0111;
static const uint16_t TYPE_STREAM_NOTIFY  = 0x0112;
static const uint16_t TYPE_STREAM_REQUEST = 0x0113;

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

/* constants: Stream-related */
static const uint8_t STREAM_TYPE_NULL      = 0;
static const uint8_t STREAM_TYPE_AUDIO     = 1;
static const uint8_t STREAM_TYPE_VIDEO     = 2;
static const uint8_t STREAM_TYPE_CLIPBOARD = 3;
/** drag & drop */
static const uint8_t STREAM_TYPE_FILE      = 4;
static const uint8_t STREAM_TYPE_PRINT     = 5;

/**
 * indicates the stream will start.
 */
static const uint8_t STREAM_NOTIFY_TYPE_START = 0;
/**
 * indicates the stream has ended.
 */
static const uint8_t STREAM_NOTIFY_TYPE_STOP  = 1;
/**
 * indicates an error occurred during streaming, or the request cannot be fulfilled.
 */
static const uint8_t STREAM_NOTIFY_TYPE_ERROR = 2;
/**
 * indicates the client received the data.
 */
static const uint8_t STREAM_NOTIFY_TYPE_ACK = 3;

static const uint8_t STREAM_DATA_FLAG_NONE   = 0b00000000;
/** marks the end of stream. */
static const uint8_t STREAM_DATA_FLAG_EOS    = 0b00000001;
/**
 * ignores time-ordered queue. (data will be processed immediately / previous data will be discarded)
 */
static const uint8_t STREAM_DATA_FLAG_URGENT = 0b00000010;


/* constants: codec enums for PROJECTION_HELLO */
static const uint8_t PROJECTION_HELLO_CODEC_NONE    = 0;
static const uint8_t PROJECTION_HELLO_CODEC_RFX     = 1;
static const uint8_t PROJECTION_HELLO_CODEC_H264    = 2;
static const uint8_t PROJECTION_HELLO_CODEC_NSCODEC = 3;

/* constants: flags for PROJECTION_HELLO */
static const uint8_t PROJECTION_HELLO_FLAG_NONE = 0b00000000;


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

struct ULIPCProjectionStart {
    uint16_t flags;
} MARK_AS_PACKED_STRUCT;

struct ULIPCProjectionStop {
    uint16_t flags;
} MARK_AS_PACKED_STRUCT;

struct ULIPCProjectionHello {
    uint8_t xrdpUlalacaVersion[32];

    uint8_t clientAddress[46];
    uint8_t clientDescription[256];

    uint32_t clientOSMajor;
    uint32_t clientOSMinor;

    uint8_t program[512];

    uint8_t codec;

    uint16_t flags;
} MARK_AS_PACKED_STRUCT;

struct ULIPCProjectionSetViewport {
    uint8_t monitorId;
    uint16_t width;
    uint16_t height;

    uint16_t flags;
} MARK_AS_PACKED_STRUCT;

struct ULIPCStreamData {
    uint8_t resourceType;
    uint64_t resourceId;

    uint64_t timestamp;
    uint32_t length;

    uint32_t crc;
    uint8_t flags;
} MARK_AS_PACKED_STRUCT;

union ULIPCStreamNotifyData {
    /**
     * dummy data for padding.
     */
    struct {
        uint8_t __pad__[32];
    } MARK_AS_PACKED_STRUCT __pad__;

    struct {
        uint8_t reason;
    } MARK_AS_PACKED_STRUCT error;
} MARK_AS_PACKED_STRUCT;

struct ULIPCStreamNotify {
    uint8_t type;
    uint8_t resourceType;
    uint64_t resourceId;

    union ULIPCStreamNotifyData data;

    uint16_t flags;
} MARK_AS_PACKED_STRUCT;

struct ULIPCStreamRequest {
    uint8_t resourceType;
    uint64_t resourceId;

    uint16_t flags;
} MARK_AS_PACKED_STRUCT;

#endif
