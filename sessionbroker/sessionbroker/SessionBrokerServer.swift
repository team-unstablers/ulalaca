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
        while (true) {
            guard let header = try? clientSocket.readCStruct(BrokerMessageHeader.self) else {
                break
            }

            if (header.messageType == REQUEST_SESSION) {
                guard let message = try? clientSocket.readCStruct(RequestSession.self) else {
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

                var response = SessionReady()
                response.sessionId = UInt64(0)
                response.isLoginSession = 0

                withUnsafeMutablePointer(to: &response.path) { dstPtr in
                    var dst = dstPtr.withMemoryRebound(to: CChar.self, capacity: 1024, { $0 })
                    cSessionPath.withUnsafeBufferPointer { srcPtr in
                        strncpy(dst, srcPtr.baseAddress, 1024)
                    }
                }

                clientSocket.writeMessage(response, type: RESPONSE_SESSION_READY)
                clientSocket.close()
            }
        }

        clientSocket.writeMessage(
                RequestRejection(reason: REJECT_REASON_AUTHENTICATION_FAILED),
                type: RESPONSE_REJECTION
        )
        clientSocket.close()
    }
}

fileprivate extension MMUnixSocketConnection {
    func writeMessage<T>(_ message: T, type: UInt16) {
        let messageLength = MemoryLayout.size(ofValue: message)

        let header = BrokerMessageHeader(
                version: UInt32(0),
                messageType: type,
                timestamp: 0,
                length: UInt64(messageLength)
        )

        let headerPtr = withUnsafePointer(to: header) { $0 }
        let messagePtr = withUnsafePointer(to: message) { $0 }

        self.write(headerPtr, size: MemoryLayout.size(ofValue: header))
        self.write(messagePtr, size: messageLength)
    }
}
