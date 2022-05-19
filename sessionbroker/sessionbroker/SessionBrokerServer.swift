//
// Created by Gyuhwan Park on 2022/04/30.
//

import Darwin
import Foundation

import CoreGraphics

class SessionBrokerServer {
    private lazy var serverSocket: MMUnixSocket = MMUnixSocket(getSocketPath())

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

    }
}
