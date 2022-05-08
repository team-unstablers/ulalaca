//
// Created by Gyuhwan Park on 2022/04/30.
//

import Darwin
import Foundation

import CoreGraphics

protocol ProjectionServerDelegate {
    func projectionServer(sessionInitiated session: ProjectionSession, id: UInt64)
    func projectionServer(sessionClosed id: UInt64)
}

class ProjectionServer {
    private let serverSocket = MMUnixSocket("/Users/unstabler/ulalaca-projector.socket")!
    private(set) public var sessions: Array<ProjectionSession> = []

    public var delegate: ProjectionServerDelegate?

    init() {
        signal(SIGPIPE, SIG_IGN)
    }

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
            delegate?.projectionServer(sessionInitiated: session, id: 0)
        }
    }
}
