//
// Created by Gyuhwan Park on 2022/04/30.
//

import Foundation

extension FixedWidthInteger {
    func writeInto(data: inout Data) {
        withUnsafeBytes(of: self) {
            data.append(contentsOf: $0)
        }
    }
}

struct MessageHeader {
    var id: UInt64
    var replyTo: UInt64 = 0
}

protocol IncomingMessage {
    init(from data: Data)
}

protocol OutgoingMessage {
    func asData() -> Data
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

    // TODO: 별도 메시지로 분리할 것
    case beginUpdate = 2
    case endUpdate = 3
}

struct ScreenUpdateNotice: OutgoingMessage {

    init(type: ScreenUpdateType, rect: CGRect, contentLength: UInt32) {
        self.type = type

        self.x = UInt16(rect.origin.x)
        self.y = UInt16(rect.origin.y)
        self.width = UInt16(rect.size.width)
        self.height = UInt16(rect.size.height)

        self.contentLength = contentLength
    }

    var type: ScreenUpdateType

    var x: UInt16
    var y: UInt16
    var width: UInt16
    var height: UInt16

    var contentLength: UInt32

    func asData() -> Data {
        var data = Data()

        type.rawValue.writeInto(data: &data)

        x.writeInto(data: &data)
        y.writeInto(data: &data)

        width.writeInto(data: &data)
        height.writeInto(data: &data)

        contentLength.writeInto(data: &data)

        return data
    }
}
