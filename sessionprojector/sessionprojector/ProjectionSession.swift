//
// Created by Gyuhwan Park on 2022/04/30.
//

import Foundation
import CoreImage


class ProjectionSession {
    public let socket: MMUnixSocketConnection

    public let mainDisplayId = CGMainDisplayID()
    public let serialQueue = DispatchQueue(label: "ProjectionSession")
    public let updateLock = DispatchSemaphore(value: 1)
    
    private(set) public var messageId: UInt64 = 1;

    init(_ socket: MMUnixSocketConnection) {
        self.socket = socket
    }

    func startSession() {
        Task {
            try! await sessionLoop()
        }
    }

    private func sessionLoop() async throws {
        var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 128)
        var bufferPtr = UnsafeMutableRawPointer(buffer)
        while (true) {
            // updateLock.signal()
            socket.read(buffer, size: 128)
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

    func movePointer(to pos:(Int, Int)) {
        let position = CGPoint(x: pos.0, y: pos.1)
        CGWarpMouseCursorPosition(position)
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
