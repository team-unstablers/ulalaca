//
// Created by Gyuhwan Park on 2022/04/30.
//

import Foundation

struct MessageHeader {
    var id: UInt64
    var replyTo: UInt64 = 0
}

enum KeyboardEventType: UInt8 {
    case keyUp = 0
    case keyDown = 1
}

struct CreateKeyboardEvent {
    var type: UInt8
    var keyCode: UInt32
    var timestamp: UInt64
}

struct QueryKeyboardState {
}

enum MouseEventType: UInt8 {
    case move = 0
    case mouseUp = 1
    case mouseDown = 2

    case wheel = 3
}

struct CreateMouseEvent {
    var type: UInt8

    var arg1: UInt32
    var arg2: UInt32
    var arg3: UInt32
    var arg4: UInt32
}

enum ScreenUpdateType: UInt8 {
    case entireScreen = 0
    case partial = 1
}

struct ScreenUpdateNotice {
    var type: UInt8

    var x: UInt16
    var y: UInt16
    var width: UInt16
    var height: UInt16

    var contentLength: UInt32
    var content: Data
}