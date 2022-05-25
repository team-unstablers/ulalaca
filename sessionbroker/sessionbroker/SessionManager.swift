//
//  SessionManager.swift
//  sessionbroker
//
//  Created by Gyuhwan Park on 2022/05/14.
//

import Foundation
import CoreFoundation
import CoreGraphics

enum SessionPreparationError: Error {
    case internalError
    case sessionNotExists
}

class SessionManager {
    public static let instance = SessionManager()

    func createCGSSession() throws -> CGSSessionID {
        let sessionId = CGSSessionCreateLoginSessionID(nil, false, false)

        return sessionId
    }

    func releaseCGSSession(which sessionID: CGSSessionID) throws {
        CGSReleaseSession(sessionID)
    }

    func switchConsoleSession(to sessionID: CGSSessionID) throws {
        CGSSwitchConsoleToSession(sessionID)
    }

    func getCGSSessionList() throws -> [[String: AnyObject]] {
        guard let cfSessionList = CGSCopySessionList()?.takeRetainedValue() as? [CFDictionary] else {
            fatalError()
        }

        return cfSessionList.map { cfSessionDict in
            cfSessionDict as! [String: AnyObject]
        }
    }

    func getSessionId(forUser username: String) throws -> String {
        let sessionList = try getCGSSessionList()
        guard let sessionDict = sessionList.filter({
            $0["kCGSSessionUserNameKey"] as? String == username
        }).first else {
            fatalError()
        }

        return String(sessionDict["kCGSSessionIDKey"] as! Int)
    }

    func isSessionExists(forUser username: String) -> Bool {
        let sessionList = try? getCGSSessionList()

        return sessionList?.filter({
            $0["kCGSSessionUserNameKey"] as? String == username
        }).count != 0
    }

    func getProjectionSessionPath(forUser username: String) throws -> String {
        let fileManager = FileManager.default
        let socketPath = fileManager.homeDirectory(forUser: username)!
                .appendingPathComponent(".ulalaca_projector.sock")
                .path

        if (!isSessionExists(forUser: username) || !fileManager.fileExists(atPath: socketPath)) {
            throw SessionPreparationError.sessionNotExists
        }

        return socketPath
    }

}

