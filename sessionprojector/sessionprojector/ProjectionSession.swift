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
            let bytesRead = socket.read(bufferPtr, size: 128)
            // updateLock.signal()
            
        }
    }

    func movePointer(to pos:(Int, Int)) {
        let position = CGPoint(x: pos.0, y: pos.1)
        CGWarpMouseCursorPosition(position)
    }

    func performClick() {

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
        let message = ScreenUpdateNotice(
            type: .partial,
            rect: rect,
            contentLength: 0
        )
        
        socket.write(message.asData())
    }

    func screenUpdateBegin() {
        let message = ScreenUpdateNotice(
            type: .beginUpdate,
            rect: CGRect(),
            contentLength: 0
        )

        socket.write(message.asData())
    }

    func screenUpdateEnd() {
        let message = ScreenUpdateNotice(
                type: .endUpdate,
                rect: CGRect(),
                contentLength: 0
        )

        socket.write(message.asData())
    }

    func screenReady(image: CGImage, rect: CGRect) {
        self.serialQueue.sync {
            let rawData = image.dataProvider!.data!

            let pointer = CFDataGetBytePtr(rawData)!
            let length = CFDataGetLength(rawData)

            /*
            let actualSize = image.width * image.height * 4
            var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: actualSize)
            var bytesPerRow = image.bytesPerRow

            let lineSize = (image.width * 4)

            for line in 0..<image.height {
                let start = bytesPerRow * line

                memcpy(buffer.advanced(by: lineSize * line), pointer.advanced(by: start), lineSize)
            }
             */

            let message = ScreenUpdateNotice(
                type: .entireScreen,
                rect: rect,
                contentLength: UInt32(length)
            )
             
            // self.updateLock.wait()
            
            self.socket.write(message.asData())
            self.socket.write(pointer, size: length)
                
                
            // buffer.deallocate()
        }
    }

    func screenResolutionChanged(to resolution: (Int, Int)) {

    }
}
