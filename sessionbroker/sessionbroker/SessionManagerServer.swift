
//
// Created by Gyuhwan Park on 2022/04/30.
//

import Darwin
import Foundation

import CoreGraphics

import UlalacaCore

class SessionManagerServer: IPCServerBase {
    private let logger = createLogger("SessionManagerServer")
    private let sessionManager = ProjectorManager.instance

    init() {
        super.init("/var/run/ulalaca_sesman.sock")
        self.delegate = self
    }
}

extension SessionManagerServer: IPCServerDelegate {
    func connectionEstablished(with client: IPCServerConnection) {

    }

    func received(header: ULIPCHeader, from client: IPCServerConnection) {
        switch (header.messageType) {
        case TYPE_ANNOUNCEMENT:
            guard let request = try? client.read(ULIPCPrivateAnnouncement.self) else {
                break
            }
            handleAnnouncement(request, header: header, from: client)
            return

        default:
            break
        }
    }

    func connectionClosed(with client: IPCServerConnection) {

    }

    func handleAnnouncement(_ announcement: ULIPCPrivateAnnouncement, header: ULIPCHeader, from client: IPCServerConnection) {
        let username = withUnsafePointer(to: announcement.username) {
            String(fromUnsafeCStr: $0, length: 64)
        }
        let endpoint = withUnsafePointer(to: announcement.endpoint) {
            String(fromUnsafeCStr: $0, length: 1024)
        }

        switch (announcement.type) {
        case ANNOUNCEMENT_TYPE_SESSION_CREATED:
            logger.info("received announcement from pid \(announcement.pid); user \(username): SESSION_CREATED")
            sessionManager.append(session: ProjectorSession(
                pid: UInt64(announcement.pid),
                username: username,
                endpoint: endpoint,
                isConsoleSession: announcement.flags & ANNOUNCEMENT_FLAG_IS_CONSOLE_SESSION != 0,
                isLoginSession: announcement.flags & ANNOUNCEMENT_FLAG_IS_LOGIN_SESSION != 0
            ))
            break

        case ANNOUNCEMENT_TYPE_SESSION_WILL_BE_DESTROYED:
            logger.info("received announcement from pid \(announcement.pid): SESSION_WILL_BE_DESTROYED")
            sessionManager.remove(where: UInt64(announcement.pid))
            break

        default:
            break
        }
    }
}

