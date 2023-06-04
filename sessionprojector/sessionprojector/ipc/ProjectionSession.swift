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
    private let logger: ULLogger

    public let socket: MMUnixSocketConnection
    public var eventInjector: EventInjector? = nil

    private var powerAssertion: PowerAssertion? = nil

    public let mainDisplayId = CGMainDisplayID()
    public let serialQueue = DispatchQueue(label: "ProjectionSession")

    private(set) public var isSessionRunning: Bool = true

    private(set) public var messageId: UInt64 = 1;
    private(set) public var suppressOutput: Bool = true

    private(set) public var screenResolution: CGSize = CGSize(width: 0, height: 0)
    private(set) public var mainViewport: ViewportInfo?

    init(_ socket: MMUnixSocketConnection) {
        self.socket = socket

        self.logger = createLogger("ProjectionSession (fd \(self.socket.descriptor()))")
        self.powerAssertion = PowerAssertion(
            for: [.declareUserIsActive, .preventUserIdleDisplaySleep, .preventUserIdleSystemSleep]
        )
    }

    func startSession(errorHandler: @escaping (Error) -> Void) {
        Task {
            do {
                try self.powerAssertion?.create()

                try await sessionLoop()
            } catch {
                errorHandler(error)
            }
        }
    }
    
    func stopSession() {
        self.isSessionRunning = false
        self.socket.close()
    }

    private func sessionLoop() async throws {
        while (isSessionRunning) {
            let header = try socket.readCStruct(ULIPCHeader.self)

            switch (header.messageType) {
            case TYPE_EVENT_KEYBOARD:
                eventInjector?.post(keyEvent: try socket.readCStruct(ULIPCKeyboardEvent.self))
                break
            case TYPE_EVENT_MOUSE_MOVE:
                eventInjector?.post(
                    mouseMoveEvent: try socket.readCStruct(ULIPCMouseMoveEvent.self),
                    scaleX: Double(screenResolution.width) / Double(mainViewport!.width),
                    scaleY: Double(screenResolution.height) / Double(mainViewport!.height)
                )
                break
            case TYPE_EVENT_MOUSE_BUTTON:
                eventInjector?.post(mouseButtonEvent: try socket.readCStruct(ULIPCMouseButtonEvent.self))
                break
            case TYPE_EVENT_MOUSE_WHEEL:
                eventInjector?.post(mouseWheelEvent: try socket.readCStruct(ULIPCMouseWheelEvent.self))
                break

            case TYPE_PROJECTION_START:
                try socket.readCStruct(ULIPCProjectionStart.self)
                suppressOutput = false
                break
            case TYPE_PROJECTION_STOP:
                try socket.readCStruct(ULIPCProjectionStop.self)
                suppressOutput = true
                break

            case TYPE_PROJECTION_SET_VIEWPORT:
                self.setViewport(with: try socket.readCStruct(ULIPCProjectionSetViewport.self))
                break

            default:
                let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(header.length), alignment: 0)
                try socket.readEx(buffer, size: Int(header.length))
            }
        }
    }

    private func setViewport(with message: ULIPCProjectionSetViewport) {
        if (message.monitorId != 0) {
            logger.debug("multi display layout is not supported yet")
            return
        }

        mainViewport = ViewportInfo(width: message.width, height: message.height)
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

        withUnsafePointer(to: header) { headerPtr in
            socket.write(headerPtr, size: MemoryLayout.size(ofValue: header))
        }
        withUnsafePointer(to: message) { messagePtr in
            socket.write(messagePtr, size: messageLength)
        }

        messageId += 1
    }

}

extension ProjectionSession: ScreenUpdateSubscriber {
    var identifier: Int {
        get { Int(socket.descriptor()) }
    }

    func screenUpdated(where rect: CGRect) {
        self.serialQueue.sync {
            let sx = mainViewport?.scaleX(Int(screenResolution.width)) ?? 1.0
            let sy = mainViewport?.scaleY(Int(screenResolution.height)) ?? 1.0

            self.writeMessage(
                    ULIPCScreenUpdateNotify(
                    type: SCREEN_UPDATE_NOTIFY_TYPE_PARTIAL,
                    rect: rect.toULIPCRect().scale(x: sx, y: sy)
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

            guard let mainViewport = self.mainViewport else {
                return
            }

            let sx = mainViewport.scaleX(Int(screenResolution.width)) ?? 1.0
            let sy = mainViewport.scaleY(Int(screenResolution.height)) ?? 1.0

            let message = ULIPCScreenUpdateCommit(
                screenRect: ULIPCRect(x: 0, y: 0, width: Int16(mainViewport.width), height: Int16(mainViewport.height)),
                bitmapLength: UInt64(length)
            )
        
            self.writeMessage(message, type: TYPE_SCREEN_UPDATE_COMMIT)
            self.socket.write(pointer, size: length)
        }
    }

    func screenResolutionChanged(to resolution: CGSize) {
        self.screenResolution = resolution
    }

}
