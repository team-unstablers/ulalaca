//
// Created by Gyuhwan Park on 2022/04/30.
//

import Foundation

class ProjectionSession {
    public let socket: MMUnixSocketConnection

    public let mainDisplayId = CGMainDisplayID()

    init(_ socket: MMUnixSocketConnection) {
        self.socket = socket
    }

    func startSession() {
        Task {
            try! await sessionLoop()
        }
    }

    private func sessionLoop() async throws {

    }

    func movePointer(to pos:(Int, Int)) {
        let position = CGPoint(x: pos.0, y: pos.1)
        CGWarpMouseCursorPosition(position)
    }

    func performClick() {

    }
}

extension ProjectionSession {}