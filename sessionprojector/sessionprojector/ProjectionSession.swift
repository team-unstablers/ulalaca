//
// Created by Gyuhwan Park on 2022/04/30.
//

import Foundation
import CoreImage
import CoreGraphics

import UlalacaCore

enum ProjectionSessionError: Error {
    case unknownError
    case socketReadError
}

class ProjectionSession {
    public let socket: MMUnixSocketConnection

    public let mainDisplayId = CGMainDisplayID()
    public let serialQueue = DispatchQueue(label: "ProjectionSession")
    public let updateLock = DispatchSemaphore(value: 1)

    private(set) public var messageId: UInt64 = 1;

    public var eventInjector: EventInjector? = nil

    init(_ socket: MMUnixSocketConnection) {
        self.socket = socket
    }

    func startSession(errorHandler: @escaping (Error) -> Void) {
        Task {
            do {
                try await sessionLoop()
            } catch {
                errorHandler(error)
            }
        }
    }

    private func sessionLoop() async throws {
        while (true) {
            let header = try socket.readCStruct(ULIPCHeader.self)

            switch (header.messageType) {
            case TYPE_EVENT_KEYBOARD:
                eventInjector?.post(keyEvent: try socket.readCStruct(ULIPCKeyboardEvent.self))
                break
            case TYPE_EVENT_MOUSE_MOVE:
                eventInjector?.post(mouseMoveEvent: try socket.readCStruct(ULIPCMouseMoveEvent.self))
                break
            case TYPE_EVENT_MOUSE_BUTTON:
                eventInjector?.post(mouseButtonEvent: try socket.readCStruct(ULIPCMouseButtonEvent.self))
                break
            case TYPE_EVENT_MOUSE_WHEEL:
                eventInjector?.post(mouseWheelEvent: try socket.readCStruct(ULIPCMouseWheelEvent.self))
                break

            default:
                let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(header.length), alignment: 0)
                try socket.readEx(buffer, size: Int(header.length))
            }
        }
    }
    
    private func writeMessage<T>(_ message: T, type: UInt16) {
        let messageLength = MemoryLayout.size(ofValue: message)
        let header = ULIPCHeader(
            messageType: type,
            id: messageId,
            replyTo: UInt64(0),
            timestamp: UInt64(Date.now.timeIntervalSince1970),
            length: UInt64(messageLength)
        )

        socket.write(withUnsafePointer(to: header) { $0 }, size: MemoryLayout.size(ofValue: header))
        socket.write(withUnsafePointer(to: message) { $0 }, size: messageLength)
        
        messageId += 1
    }

}

extension ProjectionSession: ScreenUpdateSubscriber {
    var identifier: Int {
        get { Int(socket.descriptor()) }
    }

    func screenUpdated(where rect: CGRect) {
        self.serialQueue.sync {
            self.writeMessage(
                ULIPCScreenUpdateNotify(
                    type: SCREEN_UPDATE_NOTIFY_TYPE_PARTIAL,
                    rect: ULIPCRect(
                            x: Int16(rect.origin.x),
                            y: Int16(rect.origin.y),
                            width: Int16(rect.size.width),
                            height: Int16(rect.size.height)
                    )
                ),
                type: TYPE_SCREEN_UPDATE_NOTIFY
            )
        }
    }

    func screenReady(image: CGImage, rect: CGRect) {
        self.serialQueue.sync {
            let rawData = image.dataProvider!.data!

            let pointer = CFDataGetBytePtr(rawData)!
            let length = CFDataGetLength(rawData)

            let message = ULIPCScreenUpdateCommit(
                screenRect: ULIPCRect(
                        x: Int16(rect.origin.x),
                        y: Int16(rect.origin.y),
                        width: Int16(rect.size.width),
                        height: Int16(rect.size.height)
                ),
                bitmapLength: UInt64(length)
            )
        
            self.writeMessage(message, type: TYPE_SCREEN_UPDATE_COMMIT)
            self.socket.write(pointer, size: length)
        }
    }

    func screenResolutionChanged(to resolution: (Int, Int)) {

    }

}
