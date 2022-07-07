//
//  SessionManager.swift
//  sessionbroker
//
//  Created by Gyuhwan Park on 2022/05/14.
//

import Foundation
import CoreFoundation
import CoreGraphics

struct ProjectorSession: Hashable {
    var pid: UInt64
    var username: String
    var endpoint: String

    var isConsoleSession: Bool
    var isLoginSession: Bool

    static func ==(lhs: ProjectorSession, rhs: ProjectorSession) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(username)
        hasher.combine(endpoint)
        hasher.combine(isConsoleSession)
        hasher.combine(isLoginSession)
    }
}

class ProjectorManager {
    public static let instance = ProjectorManager()
    private(set) public var sessions: Array<ProjectorSession> = [];

    private init() {
    }

    func append(session: ProjectorSession) {
        self.remove(where: session.pid)
        sessions.append(session)
    }

    func remove(where pid: UInt64) {
        sessions.removeAll { session in session.pid == pid }
    }

}

