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

    func provideSession(which session: ProjectorSession, to client: IPCServerConnection) {
        var response = ULIPCSessionRequestResolved()
        response.sessionId = session.pid
        response.isLoginSession = session.isLoginSession ? 1 : 0 // ???

        session.endpoint.toUnsafeCStrArray(
                withUnsafeMutablePointer(to: &response.path) { $0 },
                capacity: 1024
        )

        client.writeMessage(
                response,
                type: TYPE_SESSION_REQUEST_RESOLVED
        )
    }
}

extension SessionBrokerServer: IPCServerDelegate {
    func connectionEstablished(with client: IPCServerConnection) {

    }

    func received(header: ULIPCHeader, from client: IPCServerConnection) {
        switch (header.messageType) {
        case TYPE_SESSION_REQUEST:
            logger.debug("received SESSION_REQUEST")
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
        let reject = { (reason: UInt8) in
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

        logger.info("[\(username)]: authentication request from user")
        let authenticated = UserAuthenticator.authenticateUser(username, withPassword: password)
        if (!authenticated) {
            logger.info("[\(username)]: authentication failed")
            reject(REJECT_REASON_AUTHENTICATION_FAILED)
            return
        }
        logger.info("[\(username)]: authenticated")


        guard let session = ProjectorManager.instance.sessions.first(where: {
            $0.username == username
        }) ?? ProjectorManager.instance.sessions.first(where: {
            $0.isLoginSession
        }) else {
            logger.info("[\(username)]: there is no available session")
            reject(REJECT_REASON_SESSION_NOT_AVAILABLE)
            return
        }

        provideSession(which: session, to: client)
        client.close()
    }
}

