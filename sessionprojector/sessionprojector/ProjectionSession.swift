//
// Created by Gyuhwan Park on 2022/04/30.
//

import Foundation
import CoreImage
import CoreGraphics


class ProjectionSession {
    public let socket: MMUnixSocketConnection

    public let mainDisplayId = CGMainDisplayID()
    public let serialQueue = DispatchQueue(label: "ProjectionSession")
    public let updateLock = DispatchSemaphore(value: 1)
    
    let source = CGEventSource(stateID: .combinedSessionState)
    var tapPort: CFMachPort

    private(set) public var messageId: UInt64 = 1;

    init(_ socket: MMUnixSocketConnection) {
        self.socket = socket
        self.tapPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: UInt64(CGEventType.mouseMoved.rawValue),
            callback: { (proxy, type, event, refcon) in
                nil
            },
            userInfo: nil
        )!
    }

    func startSession() {
        Task {
            try! await sessionLoop()
        }
    }

    private func sessionLoop() async throws {
        var buffer = UnsafeMutableRawPointer.allocate(byteCount: 256, alignment: 0)
        while (true) {
            socket.read(buffer, size: 34)

            let header = MessageHeader.from(buffer)
            socket.read(buffer, size: Int(header.length))

            if (header.messageType == KeyboardEvent.getType()) {
                let event = KeyboardEvent(from: buffer)
                print("sending keyevent \(event.keyCode) \(event.type)")

                CGEvent(
                    keyboardEventSource: nil,
                    virtualKey: CGKeyCode(event.keyCode),
                    keyDown: event.type == 2
                )?.post(tap: .cgSessionEventTap)
            } else if (header.messageType == MouseMoveEvent.getType()) {
                let event = MouseMoveEvent(from: buffer)
                print("moving mouse to \(event.x), \(event.y)")

                CGEvent(
                    mouseEventSource: nil,
                    mouseType: .mouseMoved,
                    mouseCursorPosition: CGPoint(x: Int(event.x), y: Int(event.y)),
                    mouseButton: .left
                )?.post(tap: .cgSessionEventTap)
            } else if (header.messageType == MouseButtonEvent.getType()) {
                let event = MouseButtonEvent(from: buffer)
                print("sending mouseButton \(event.button) \(event.type)")
                
                var mouseType: CGEventType = .null

                if (event.button == 0) {
                    mouseType = event.type == 1 ? .leftMouseUp : .leftMouseDown
                } else if (event.button == 1) {
                    mouseType = event.type == 1 ? .rightMouseUp : .rightMouseDown
                }

                CGEvent(
                    mouseEventSource: nil,
                    mouseType: mouseType,
                    mouseCursorPosition: CGEvent(source: nil)!.location,
                    mouseButton: .left
                )?.post(tap: .cgSessionEventTap)
            }
        }
    }
    
    private func writeMessage<T>(_ message: T) where T: OutgoingMessage {
        let body = message.asData()
        let header = MessageHeader(
            messageType: T.getType(),
            id: messageId,
            timestamp: UInt64(Date.now.timeIntervalSince1970),
            length: UInt64(body.count)
        ).asData()
        
        socket.write(header)
        socket.write(body)
        
        messageId += 1
    }
}

extension MMUnixSocketConnection {
    func write(_ data: Data) {
        data.withUnsafeBytes { ptr in
            self.write(UnsafeRawPointer(ptr)!, size: data.count)
        }
    }
}

extension ProjectionSession: ScreenUpdateSubscriber {
    func screenUpdated(where rect: CGRect) {
        self.serialQueue.sync {
            self.writeMessage(ScreenUpdateEvent(
                type: .partial,
                rect: rect
            ))
        }
    }

    func screenReady(image: CGImage, rect: CGRect) {
        self.serialQueue.sync {
            let rawData = image.dataProvider!.data!

            let pointer = CFDataGetBytePtr(rawData)!
            let length = CFDataGetLength(rawData)

            let message = ScreenCommitUpdate(
                rect: rect,
                bitmapLength: UInt64(length)
            )
        
            self.writeMessage(message)
            self.socket.write(pointer, size: length)
        }
    }

    func screenResolutionChanged(to resolution: (Int, Int)) {

    }
}
