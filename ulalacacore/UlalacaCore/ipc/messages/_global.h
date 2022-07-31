#ifndef ULALACA_CORE_IPC_MESSAGES_GLOBAL_H
#define ULALACA_CORE_IPC_MESSAGES_GLOBAL_H

#include <stdint.h>

/**
 * FIXME: naming
 */
#define MARK_AS_PACKED_STRUCT __attribute__ ((packed))

struct ULIPCRect {
    short x;
    short y;
    short width;
    short height;
} MARK_AS_PACKED_STRUCT;

struct ULIPCHeader {
    uint16_t messageType;

    uint64_t id;
    uint64_t replyTo;

    uint64_t timestamp;

    uint64_t length;
} MARK_AS_PACKED_STRUCT;


#endif