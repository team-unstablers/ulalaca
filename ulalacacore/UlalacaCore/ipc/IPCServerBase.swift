//
// Created by Gyuhwan Park on 2022/06/28.
//

import Foundation

public protocol IPCServerDelegate {
    func connectionEstablished(with client: IPCServerConnection);
    func received(header: ULIPCHeader, from client: IPCServerConnection);
    func connectionClosed(with client: IPCServerConnection);
}

open class IPCServerBase {
    public let socketPath: String;
    private lazy var serverSocket: MMUnixSocket = MMUnixSocket(socketPath)

    public var delegate: IPCServerDelegate? = nil

    public init(_ socketPath: String) {
        signal(SIGPIPE, SIG_IGN)

        self.socketPath = socketPath;
    }

    public func start() {
        serverSocket.bind()
        chmod(socketPath.cString(using: .utf8), S_IRWXU | S_IRWXG | S_IRWXO);

        serverSocket.listen()

        while (true) {
            guard let clientSocket = serverSocket.accept() else {
                continue
            }

            let connection = IPCServerConnection(clientSocket)

            Task {
                delegate?.connectionEstablished(with: connection)
                await clientLoop(connection)
                delegate?.connectionClosed(with: connection)

                clientSocket.close()
            }
        }
    }

    private func clientLoop(_ client: IPCServerConnection) async {
        while (true) {
            guard let header = try? client.read(ULIPCHeader.self) else {
                break
            }

            delegate?.received(header: header, from: client)
        }
    }
}

public class IPCServerConnection {
    private(set) public var connection: MMUnixSocketConnection
    private(set) public var id: UInt64 = 0

    init(_ connection: MMUnixSocketConnection) {
        self.connection = connection
    }

    public func read<T>(_ type: T.Type) throws -> T {
        return try self.connection.readCStruct(type)
    }

    public func writeMessage<T>(_ message: T, type: UInt16, replyTo: UInt64 = 0) {
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

        connection.write(headerPtr, size: MemoryLayout.size(ofValue: header))
        connection.write(messagePtr, size: messageLength)

        id = id + 1
    }

    public func close() {
        self.connection.close()
    }
}
