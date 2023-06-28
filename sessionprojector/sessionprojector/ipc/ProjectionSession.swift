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

enum ClientCodec: UInt8 {
    case none = 0
    case rfx = 1
    case h264 = 2
    case nsCodec = 3
}


struct ClientInfo: Hashable {
    public static let CLIENT_ID_UNKNOWN = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var id: UUID

    var xrdpUlalacaVersion: String
    var clientAddress: String
    var clientDescription: String
    var clientOSMajor: Int
    var clientOSMinor: Int

    var program: String

    var codec: ClientCodec

    var flags: Int

    static func from(ipc message: ULIPCProjectionHello) -> ClientInfo {
        return ClientInfo(
            id: UUID(),
            xrdpUlalacaVersion: withUnsafePointer(to: message.xrdpUlalacaVersion) { String(fromUnsafeCStr: $0, length: 32) },
            clientAddress: withUnsafePointer(to: message.clientAddress) { String(fromUnsafeCStr: $0, length: 46) },
            clientDescription: withUnsafePointer(to: message.clientDescription) { String(fromUnsafeCStr: $0, length: 256) },
            clientOSMajor: Int(message.clientOSMajor),
            clientOSMinor: Int(message.clientOSMinor),
            program: withUnsafePointer(to: message.program) { String(fromUnsafeCStr: $0, length: 512) },
            codec: ClientCodec(rawValue: message.codec) ?? .none,
            flags: Int(message.flags)
        )
    }

    static func unknown() -> ClientInfo {
        return ClientInfo(
            id: CLIENT_ID_UNKNOWN,
            xrdpUlalacaVersion: "Unknown",
            clientAddress: "Unknown",
            clientDescription: "Unknown",
            clientOSMajor: 0,
            clientOSMinor: 0,
            program: "Unknown",
            codec: .none,
            flags: 0
        )
    }
}

class ProjectionSession: Identifiable {
    private let logger: ULLogger

    public let socket: MMUnixSocketConnection
    public var eventInjector: EventInjector? = nil

    private var powerAssertion: PowerAssertion? = nil

    public let mainDisplayId = CGMainDisplayID()
    public let serialQueue = DispatchQueue(label: "ProjectionSession")

    public var id: UUID

    private(set) public var clientInfo: ClientInfo = ClientInfo.unknown()

    private(set) public var isSessionRunning: Bool = true

    private(set) public var messageId: UInt64 = 1;
    private(set) public var suppressOutput: Bool = true

    private(set) public var screenResolution: CGSize = CGSize(width: 0, height: 0)
    private(set) public var scaleFactor: CGFloat = 1.0
    private(set) public var mainViewport: ViewportInfo = ViewportInfo(width: 640, height: 480)

    init(_ socket: MMUnixSocketConnection) {
        self.id = UUID()
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
                // viewport      -> frameSize      -> screenResolution (actual)
                // (1600x900@1x) -> (1920x1080@1x) -> (1920x1080@2x) (3840x2160)

                let sx = screenResolution.width * scaleFactor / CGFloat(mainViewport.width)
                let sy = screenResolution.height * scaleFactor / CGFloat(mainViewport.height)

                eventInjector?.post(
                    mouseMoveEvent: try socket.readCStruct(ULIPCMouseMoveEvent.self),
                    scaleX: sx,
                    scaleY: sy
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
            case TYPE_PROJECTION_HELLO:
                // ???
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

    public func readHello(timeout: Double = 0.5) -> Bool {
        logger.debug("ProjectionSession::readHello(): timeout is not implemented yet")

        guard let header = try? socket.readCStruct(ULIPCHeader.self) else {
            return false
        }

        if (header.messageType != TYPE_PROJECTION_HELLO) {
            return false
        }

        guard let message = try? socket.readCStruct(ULIPCProjectionHello.self) else {
            return false
        }
        self.clientInfo = ClientInfo.from(ipc: message)

        return true
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

extension ProjectionSession: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(socket.descriptor())
    }

    public static func ==(lhs: ProjectionSession, rhs: ProjectionSession) -> Bool {
        return lhs.hashValue == rhs.hashValue
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
                    rect: rect.toULIPCRect()
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
                screenRect: ULIPCRect(x: 0, y: 0, width: Int16(mainViewport.width), height: Int16(mainViewport.height)),
                bitmapLength: UInt64(length)
            )
        
            self.writeMessage(message, type: TYPE_SCREEN_UPDATE_COMMIT)
            self.socket.write(pointer, size: length)
        }
    }

    func screenResolutionChanged(to resolution: CGSize, scaleFactor: Double) {
        self.screenResolution = resolution
    }

}
