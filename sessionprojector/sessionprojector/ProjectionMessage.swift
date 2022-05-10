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

extension UnsafeRawPointer {
    func unalignedLoad<T>(offset: Int, as: T.Type) -> T {
        self.advanced(by: offset).assumingMemoryBound(to: T.self).pointee
    }
}

struct MessageHeader {

    static func from(_ pointer: UnsafeRawPointer) -> MessageHeader {
        return MessageHeader(
            messageType: pointer.unalignedLoad(offset: 0, as: UInt16.self),

            id: pointer.unalignedLoad(offset: 2, as: UInt64.self),
            replyTo: pointer.unalignedLoad(offset: 10, as: UInt64.self),

            timestamp: pointer.unalignedLoad(offset: 18, as: UInt64.self),

            length: pointer.unalignedLoad(offset: 26, as: UInt64.self)
        )
    }

    var messageType: UInt16
    
    var id: UInt64
    var replyTo: UInt64 = 0
    
    var timestamp: UInt64
    
    var length: UInt64
    
    func asData() -> Data {
        var data = Data()
    
        messageType.writeInto(data: &data)
        
        id.writeInto(data: &data)
        replyTo.writeInto(data: &data)
        
        timestamp.writeInto(data: &data)
        
        length.writeInto(data: &data)
        
        return data
    }
}

protocol IncomingMessage {
    static func getType() -> UInt16
    init(from pointer: UnsafeRawPointer)
}

protocol OutgoingMessage {
    static func getType() -> UInt16
    func asData() -> Data
}

enum KeyboardEventType: UInt8 {
    case keyUp = 0
    case keyDown = 1
}

struct KeyboardEvent: IncomingMessage {
    static func getType() -> UInt16 {
        0x0311
    }

    var type: UInt8
    var keyCode: UInt32

    var flags: UInt16

    init() {
        type = 0
        keyCode = 0
        flags = 0
    }

    init(from pointer: UnsafeRawPointer) {
        self.init()

        type = pointer.unalignedLoad(offset: 0, as: UInt8.self)
        keyCode = pointer.unalignedLoad(offset: 1, as: UInt32.self)
        flags = pointer.unalignedLoad(offset: 5, as: UInt16.self)
    }

}

struct QueryKeyboardState {
}

enum MouseEventType: UInt8 {
    case move = 0
    case mouseUp = 1
    case mouseDown = 2

    case wheel = 3
}

struct MouseMoveEvent: IncomingMessage {
    static func getType() -> UInt16 {
        0x0321
    }

    var x: UInt16
    var y: UInt16

    var flags: UInt16

    init() {
        x = 0
        y = 0

        flags = 0
    }

    init(from pointer: UnsafeRawPointer) {
        self.init()

        x = pointer.unalignedLoad(offset: 0, as: UInt16.self)
        y = pointer.unalignedLoad(offset: 2, as: UInt16.self)

        flags = pointer.unalignedLoad(offset: 4, as: UInt16.self)
    }
}


struct MouseButtonEvent: IncomingMessage {
    static func getType() -> UInt16 {
        0x0322
    }

    var type: UInt8
    var button: UInt8

    var flags: UInt16

    init() {
        type = 0
        button = 0

        flags = 0
    }

    init(from pointer: UnsafeRawPointer) {
        self.init()

        type = pointer.unalignedLoad(offset: 0, as: UInt8.self)
        button = pointer.unalignedLoad(offset: 1, as: UInt8.self)

        flags = pointer.unalignedLoad(offset: 2, as: UInt16.self)
    }
}

enum ScreenUpdateType: UInt8 {
    case entireScreen = 0
    case partial = 1
}

struct ScreenUpdateEvent: OutgoingMessage {
    static func getType() -> UInt16 {
        return 0x0101
    }
    
    init(type: ScreenUpdateType, rect: CGRect) {
        self.type = type
        self.x = UInt16(max(rect.origin.x, 0))
        self.y = UInt16(max(rect.origin.y, 0))
        self.width = UInt16(rect.size.width)
        self.height = UInt16(rect.size.height)
    }

    var type: ScreenUpdateType
    
    var x: UInt16
    var y: UInt16
    var width: UInt16
    var height: UInt16

    func asData() -> Data {
        var data = Data()
        
        type.rawValue.writeInto(data: &data)

        x.writeInto(data: &data)
        y.writeInto(data: &data)

        width.writeInto(data: &data)
        height.writeInto(data: &data)

        return data
    }
}

struct ScreenCommitUpdate: OutgoingMessage {

    static func getType() -> UInt16 {
        return 0x0102
    }
    
    init(rect: CGRect, bitmapLength: UInt64) {
        self.x = UInt16(rect.origin.x)
        self.y = UInt16(rect.origin.y)
        self.width = UInt16(rect.size.width)
        self.height = UInt16(rect.size.height)

        self.bitmapLength = bitmapLength
    }

    var x: UInt16
    var y: UInt16
    var width: UInt16
    var height: UInt16

    var bitmapLength: UInt64

    func asData() -> Data {
        var data = Data()

        x.writeInto(data: &data)
        y.writeInto(data: &data)

        width.writeInto(data: &data)
        height.writeInto(data: &data)

        bitmapLength.writeInto(data: &data)

        return data
    }
}
