//
// Created by Gyuhwan Park on 2022/06/29.
//

import Foundation

import UlalacaCore

class SessionManagerClient: IPCClientBase {
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
