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
        var buffer = UnsafeMutableRawPointer.allocate(byteCount: 256, alignment: 0)
        while (true) {
            try socket.readEx(buffer, size: 34)

            let header = MessageHeader.from(buffer)
            try socket.readEx(buffer, size: Int(header.length))

            if (header.messageType == KeyboardEvent.getType()) {
                let event = KeyboardEvent(from: buffer)

                eventInjector?.post(keyEvent: event)
            } else if (header.messageType == MouseMoveEvent.getType()) {
                let event = MouseMoveEvent(from: buffer)

                eventInjector?.post(mouseMoveEvent: event)
            } else if (header.messageType == MouseButtonEvent.getType()) {
                let event = MouseButtonEvent(from: buffer)
                // print("sending mouseButton \(event.button) \(event.type)")

                eventInjector?.post(mouseButtonEvent: event)
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

extension ProjectionSession: ScreenUpdateSubscriber {
    var identifier: Int {
        get { Int(socket.descriptor()) }
    }

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
