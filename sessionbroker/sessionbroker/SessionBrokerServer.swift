//
// Created by Gyuhwan Park on 2022/04/30.
//

import Darwin
import Foundation

import CoreGraphics

import UlalacaCore

class SessionBrokerServer {
    private lazy var serverSocket: MMUnixSocket = MMUnixSocket(getSocketPath())

    private let userAuthenticator = UserAuthenticator()
    private let sessionManager = SessionManager()


    init() {
        signal(SIGPIPE, SIG_IGN)
    }

    func getSocketPath() -> String {
        return "/var/run/ulalaca_broker.sock"
    }

    func start() {
        serverSocket.bind()
        serverSocket.listen()

        while (true) {
            guard let clientSocket = serverSocket.accept() else {
                continue
            }

            Task {
                await clientLoop(clientSocket)
            }
        }
    }

    func clientLoop(_ clientSocket: MMUnixSocketConnection) async {
        var messageId: UInt64 = 0

        func getMessageId() -> UInt64 {
            messageId += 1;

            return messageId
        }

        while (true) {
            guard let header = try? clientSocket.readCStruct(ULIPCHeader.self) else {
                break
            }

            if (header.messageType == TYPE_SESSION_REQUEST) {
                guard let message = try? clientSocket.readCStruct(ULIPCSessionRequest.self) else {
                    break
                }
                let username = withUnsafePointer(to: message.username) { String(fromUnsafeCStr: $0, length: 64) }
                let authenticated = userAuthenticator.authenticate(
                        username,
                        with: withUnsafePointer(to: message.password) { String(fromUnsafeCStr: $0, length: 256) }
                )

                if (!authenticated) {
                    break
                }

                guard let sessionPath = try? sessionManager.getProjectionSessionPath(forUser: username) else {
                    break
                }
                let cSessionPath = sessionPath.cString(using: String.Encoding.utf8)!

                var response = ULIPCSessionRequestResolved()
                response.sessionId = UInt64(0)
                response.isLoginSession = 0

                // :'(
                withUnsafeMutablePointer(to: &response.path) { dstPtr in
                    var dst = dstPtr.withMemoryRebound(to: CChar.self, capacity: 1024, { $0 })
                    cSessionPath.withUnsafeBufferPointer { srcPtr in
                        strncpy(dst, srcPtr.baseAddress, 1024)
                    }
                }

                clientSocket.writeMessage(
                        response,
                        type: TYPE_SESSION_REQUEST_RESOLVED,
                        id: getMessageId()
                )
                clientSocket.close()
            }
        }

        clientSocket.writeMessage(
                ULIPCSessionRequestRejected(reason: REJECT_REASON_AUTHENTICATION_FAILED),
                type: TYPE_SESSION_REQUEST_REJECTED,
                id: getMessageId()
        )
        clientSocket.close()
    }
}

fileprivate extension MMUnixSocketConnection {
    func writeMessage<T>(_ message: T, type: UInt16, id: UInt64 = 0) {
        let messageLength = MemoryLayout.size(ofValue: message)
        let header = ULIPCHeader(
                messageType: type,
                id: id, // FIXME
                replyTo: UInt64(0), // FIXME

                timestamp: UInt64(Date.now.timeIntervalSince1970 * 1000),

                length: UInt64(messageLength)
        )

        let headerPtr = withUnsafePointer(to: header) { $0 }
        let messagePtr = withUnsafePointer(to: message) { $0 }

        self.write(headerPtr, size: MemoryLayout.size(ofValue: header))
        self.write(messagePtr, size: messageLength)
    }
}
