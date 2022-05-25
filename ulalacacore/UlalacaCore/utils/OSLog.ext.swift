//
// Created by Gyuhwan Park on 2022/05/23.
//

import os

import Foundation

public func createLogger(_ tag: String) -> OSLog {
    return OSLog(subsystem: Bundle.main.bundleIdentifier!, category: tag)
}

public extension OSLog {
    public func debug(_ message: String) {
        os_log("[DEBUG] %@", log: self, type: .debug, message)
    }
    public func log(_ message: String) {
        os_log("[LOG] %@", log: self, type: .default, message)
    }
    public func info(_ message: String) {
        os_log("[INFO] %@", log: self, type: .info, message)
    }
    public func error(_ message: String) {
        os_log("[ERROR] %@", log: self, type: .error, message)
    }
    public func fatal(_ message: String) {
        os_log("[FATAL] %@", log: self, type: .fault, message)
    }
}
