//
// Created by Gyuhwan Park on 2022/04/30.
//

import Darwin
import Foundation

import CoreGraphics

import UlalacaCore

class SessionBrokerServer: IPCServerBase {
    private let logger = createLogger("SessionBrokerServer")
    private let userAuthenticator = UserAuthenticator()

    init() {
        super.init("/var/run/ulalaca_broker.sock")
        self.delegate = self
    }
}

extension SessionBrokerServer: IPCServerDelegate {
    func connectionEstablished(with client: IPCServerConnection) {

    }

    func received(header: ULIPCHeader, from client: IPCServerConnection) {
        switch (header.messageType) {
        case TYPE_SESSION_REQUEST:
            guard let request = try? client.read(ULIPCSessionRequest.self) else {
                break
            }
            handleSessionRequest(request, header: header, from: client)
            return

        default:
            break
        }

        client.close()
    }

    func connectionClosed(with client: IPCServerConnection) {

    }

    func handleSessionRequest(_ request: ULIPCSessionRequest, header: ULIPCHeader, from client: IPCServerConnection) {
        let reject = {
            client.writeMessage(
                ULIPCSessionRequestRejected(reason: REJECT_REASON_AUTHENTICATION_FAILED),
                type: TYPE_SESSION_REQUEST_REJECTED,
                replyTo: header.id
            )
            client.close()
        }

        let username = withUnsafePointer(to: request.username) {
            String(fromUnsafeCStr: $0, length: 64)
        }
        let password = withUnsafePointer(to: request.password) {
            String(fromUnsafeCStr: $0, length: 256)
        }

        let authenticated = UserAuthenticator.authenticateUser(username, withPassword: password)
        if (!authenticated) {
            reject()
            return
        }

        guard let projectorInstance = ProjectorManager.instance.instances.first(where: {
            $0.username == username
        }) ?? ProjectorManager.instance.instances.first(where: {
            $0.isLoginSession
        }) else {
            reject()
            return
        }

        var response = ULIPCSessionRequestResolved()
        response.sessionId = UInt64(0)
        response.isLoginSession = 0

        projectorInstance.endpoint.toUnsafeCStrArray(
                withUnsafeMutablePointer(to: &response.path) { $0 },
                capacity: 1024
        )

        client.writeMessage(
                response,
                type: TYPE_SESSION_REQUEST_RESOLVED
        )
        client.close()
    }
}

