//
//  PIDLock.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2023/01/28.
//

import Foundation
import Cocoa

struct PIDLockError: Error {
    
}

class PIDLock {
    private static let fileManager: FileManager = FileManager.default
    
    private enum LockStatus {
        case unlocked
        case locked
    }

    static func lockFileOf(_ bundleId: String) -> URL {
        fileManager
                .homeDirectoryForCurrentUser
                .appendingPathComponent("\(bundleId).pidlock")
    }

    static func isProcessExists(_ bundleId: String, pid: pid_t) -> Bool {
        let applications = NSWorkspace.shared.runningApplications

        return !(applications.filter { app in
            app.bundleIdentifier == bundleId && app.processIdentifier == pid
        }.isEmpty)
    }
    
    /**
     acquires PID Lock.
     */
    static func acquire(_ bundleId: String, force: Bool = false) throws -> PIDLock {
        if (!force && isLocked(bundleId)) {
            throw PIDLockError()
        }

        try? fileManager.removeItem(atPath: lockFileOf(bundleId).path)

        let pid = ProcessInfo.processInfo.processIdentifier
        let lock = PIDLock(bundleId, pid: pid)
        try lock.writeLockfile()

        return lock
    }
        
    static func isLocked(_ bundleId: String) -> Bool {
        let pid = pidOf(bundleId)
        return isProcessExists(bundleId, pid: pid)
    }
    
    private static func pidOf(_ bundleId: String) -> pid_t {
        let lockfilePath = lockFileOf(bundleId)

        if (fileManager.fileExists(atPath: lockfilePath.path)),
            let data = try? Data(contentsOf: lockfilePath),
            let pidStr = String(data: data, encoding: .utf8),
            let pid = pid_t(pidStr)
        {
            return pid
        }

        return -1
    }

    private let bundleId: String
    private let pid: pid_t

    private init(_ bundleId: String, pid: pid_t) {
        assert(pid != -1)

        self.bundleId = bundleId
        self.pid = pid
    }

    deinit {
        removeLockfile()
    }

    private func writeLockfile() throws {
        let lockfilePath = PIDLock.lockFileOf(bundleId)
        try String(pid).write(to: lockfilePath, atomically: true, encoding: .utf8)
    }

    private func removeLockfile() {
        let lockfilePath = PIDLock.lockFileOf(bundleId)
        try? PIDLock.fileManager.removeItem(at: lockfilePath)
    }
    
}
