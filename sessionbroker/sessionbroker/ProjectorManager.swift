//
//  SessionManager.swift
//  sessionbroker
//
//  Created by Gyuhwan Park on 2022/05/14.
//

import Foundation
import CoreFoundation
import CoreGraphics

struct ProjectorInstance: Hashable {
    var pid: UInt64
    var username: String
    var endpoint: String

    var isConsoleSession: Bool
    var isLoginSession: Bool

    static func ==(lhs: ProjectorInstance, rhs: ProjectorInstance) -> Bool {
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
    private(set) public var instances: Array<ProjectorInstance> = [];

    private init() {
    }

    func append(session: ProjectorInstance) {
        self.remove(where: session.pid)
        instances.append(session)
    }

    func remove(where pid: UInt64) {
        instances.removeAll { session in session.pid == pid }
    }

}

