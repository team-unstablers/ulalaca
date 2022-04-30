//
// Created by Gyuhwan Park on 2022/04/30.
//

import Darwin
import Foundation

import CoreGraphics

class ProjectionServer {
    private let serverSocket = MMUnixSocket("/User/unstabler/ulalaca-projector.socket")!
    private(set) public var sessions: Array<ProjectionSession> = []

    func start() {
        serverSocket.bind()
        serverSocket.listen()

        while (true) {
            guard let clientSocket = serverSocket.accept() else {
                continue
            }
            let session = ProjectionSession.init(clientSocket)

            sessions.append(session)
            session.startSession()
        }
    }
}
