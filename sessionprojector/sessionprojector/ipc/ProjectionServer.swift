//
// Created by Gyuhwan Park on 2022/04/30.
//

import Darwin
import Foundation

import CoreGraphics

import UlalacaCore

protocol ProjectionServerDelegate {
    func projectionServer(sessionInitiated session: ProjectionSession, id: UInt64)
    func projectionServer(sessionClosed session: ProjectionSession, id: UInt64)
}

class ProjectionServer {
    private let logger = createLogger("ProjectionServer")
    
    
    private lazy var serverSocket: MMUnixSocket = MMUnixSocket(getSocketPath())
    private(set) public var isServerRunning = true
    
    private(set) public var sessions: Array<ProjectionSession> = []

    public var delegate: ProjectionServerDelegate?

    init() {
        signal(SIGPIPE, SIG_IGN)
    }

    func getSocketPath() -> String {
        return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".ulalaca_projector.sock", isDirectory: false)
                .path
    }

    func start() throws {
        try ObjC.evaluate {
            serverSocket.bind()
            serverSocket.listen()
        }

        while (isServerRunning) {
            do {
                try ObjC.evaluate {
                    guard let clientSocket = serverSocket.accept() else {
                        return
                    }
                    let session = ProjectionSession.init(clientSocket)
                    sessions.append(session)

                    if (!session.readHello()) {
                        session.stopSession()
                        return
                    }

                    delegate?.projectionServer(sessionInitiated: session, id: 0)

                    session.startSession(errorHandler: { error in
                        if let index = self.sessions.index(where: { $0.socket.descriptor() == session.socket.descriptor() }) {
                            self.sessions.remove(at: index)
                        }

                        self.delegate?.projectionServer(sessionClosed: session, id: 0)
                    })
                }
            } catch let error as NestedNSExceptionError {
                // TODO: handle error
                logger.error(error.localizedDescription)
                continue
            }
        }
    }
    
    func disconnectAll() {
        sessions.forEach { session in
            logger.info("closing session #\(session.socket.descriptor())")
            session.stopSession()
        }
    }
    
    func stop() {
        isServerRunning = false
        
        disconnectAll()
        serverSocket.close()
    }
}
