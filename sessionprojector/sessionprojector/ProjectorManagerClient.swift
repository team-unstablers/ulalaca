//
// Created by Gyuhwan Park on 2022/06/29.
//

import Foundation

import UlalacaCore


protocol IPCClientDelegate {
    func connected()
    func received(header: ULIPCHeader)
    func disconnected()
}

class IPCClientBase {
    public let socketPath: String;
    private lazy var socket: MMUnixSocket = MMUnixSocket(socketPath)

    public var delegate: IPCClientDelegate? = nil

    private(set) public var id: UInt64 = 0

    init(_ socketPath: String) {
        signal(SIGPIPE, SIG_IGN)

        self.socketPath = socketPath;
    }

    func read<T>(_ type: T.Type) throws -> T {
        return try self.socket.readCStruct(type)
    }

    func writeMessage<T>(_ message: T, type: UInt16, replyTo: UInt64 = 0) {
        let messageLength = MemoryLayout.size(ofValue: message)
        let header = ULIPCHeader(
                messageType: type,
                id: id,
                replyTo: replyTo,

                timestamp: UInt64(Date.now.timeIntervalSince1970 * 1000),

                length: UInt64(messageLength)
        )

        let headerPtr = withUnsafePointer(to: header) { $0 }
        let messagePtr = withUnsafePointer(to: message) { $0 }

        socket.write(headerPtr, size: MemoryLayout.size(ofValue: header))
        socket.write(messagePtr, size: messageLength)

        id = id + 1
    }

    private func clientLoop() async {
        while (true) {
            guard let header = try? read(ULIPCHeader.self) else {
                break
            }

            delegate?.received(header: header)
        }
    }

    func start() {
        Task {
            socket.connect()
            delegate?.connected()
            await clientLoop()
            socket.close()
        }
    }
}

class ProjectorManagerClient: IPCClientBase {
    init() {
        super.init("/var/run/ulalaca_sesman.sock")
    }

    func announceSelf(_ type: UInt8, endpoint: String, isConsoleSession: Bool = false, isLoginSession: Bool = false) {
        var message = ULIPCPrivateAnnouncement()
        message.type = type
        message.pid = getpid()

        NSUserName().toUnsafeCStrArray(
                withUnsafeMutablePointer(to: &message.username) { $0 },
                capacity: 64
        )

        endpoint.toUnsafeCStrArray(
                withUnsafeMutablePointer(to: &message.endpoint) { $0 },
                capacity: 1024
        )

        message.flags =
                (isConsoleSession ? ANNOUNCEMENT_FLAG_IS_CONSOLE_SESSION : 0) |
                (isLoginSession   ? ANNOUNCEMENT_FLAG_IS_LOGIN_SESSION : 0)

        writeMessage(message, type: TYPE_ANNOUNCEMENT)
    }
}
