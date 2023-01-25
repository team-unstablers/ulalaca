//
// Created by Gyuhwan Park on 2022/07/07.
//

import Foundation

public protocol IPCClientDelegate {
    func connected()
    func received(header: ULIPCHeader)
    func disconnected()
}

open class IPCClientBase {
    public let socketPath: String;
    private lazy var socket: MMUnixSocket = MMUnixSocket(socketPath)

    public var delegate: IPCClientDelegate? = nil

    private(set) public var id: UInt64 = 0

    public init(_ socketPath: String) {
        signal(SIGPIPE, SIG_IGN)

        self.socketPath = socketPath;
    }

    open func read<T>(_ type: T.Type) throws -> T {
        return try self.socket.readCStruct(type)
    }

    open func writeMessage<T>(_ message: T, type: UInt16, replyTo: UInt64 = 0) {
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

    open func start() throws {
        sleep(5) // FIXME: wait until server starts
        
        try ObjC.evaluate {
            socket.connect()
            delegate?.connected()
        }
        Task {
            await clientLoop()
            socket.close()
        }

    }
}
