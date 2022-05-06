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
    init(from data: Data)
}

protocol OutgoingMessage {
    static func getType() -> UInt16
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
}

struct ScreenUpdateEvent: OutgoingMessage {
    static func getType() -> UInt16 {
        return 0x0101
    }
    
    init(type: ScreenUpdateType, rect: CGRect) {
        self.type = type
        self.x = UInt16(rect.origin.x)
        self.y = UInt16(rect.origin.y)
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
