//
// Created by Gyuhwan Park on 2022/07/07.
//

import Foundation

public protocol IPCClientDelegate {
    func connected()
    func received(header: ULIPCHeader)
    func disconnected()
    func error(what error: Error?)
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

        withUnsafePointer(to: header) { headerPtr in
            socket.write(headerPtr, size: MemoryLayout.size(ofValue: header))
        }
        withUnsafePointer(to: message) { messagePtr in
            socket.write(messagePtr, size: messageLength)
        }


        id = id + 1
    }

    private func clientLoop() async {
        do {
            while (true) {
                let header = try read(ULIPCHeader.self)
                delegate?.received(header: header)
            }
        } catch {
            delegate?.error(what: error)
        }
    }

    open func start() {
        do {
            try ObjC.evaluate {
                socket.connect()
                delegate?.connected()
            }
        } catch {
            delegate?.error(what: error)
            return
        }

        Task {
            await clientLoop()
            socket.close()
        }

    }
}
