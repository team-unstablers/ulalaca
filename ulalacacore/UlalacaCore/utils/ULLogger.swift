//
// Created by Gyuhwan Park on 2022/05/23.
//

import os

import Foundation

public protocol ULLogger {
    func debug(_ message: String)
    func info(_ message: String)
    func error(_ message: String)
    func fatal(_ message: String)
}

open class ULConsoleLogger: ULLogger {
    private let subsystem: String
    private let tag: String

    private var now: String {
        get {
            Date.now.formatted()
        }
    }

    init(tag: String, subsystem: String) {
        self.subsystem = subsystem
        self.tag = tag
    }

    public func write(level: String, tag: String, message: String) {
        fputs("[\(now)][\(tag):\(level)] \(message)\n", stderr)
    }

    public func debug(_ message: String) {
        write(level: "DEBUG", tag: tag, message: message)
    }

    public func info(_ message: String) {
        write(level: "INFO", tag: tag, message: message)
    }

    public func error(_ message: String) {
        write(level: "ERROR", tag: tag, message: message)
    }

    public func fatal(_ message: String) {
        write(level: "FATAL", tag: tag, message: message)
    }
}

extension OSLog: ULLogger {
    public func debug(_ message: String) {
        os_log("[DEBUG] %@", log: self, type: .debug, message)
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

public func createLogger(_ tag: String, subsystem: String = "Ulalaca") -> ULConsoleLogger {
    return ULConsoleLogger(tag: tag, subsystem: subsystem)
}

public func createOSLogger(_ tag: String, subsystem: String = "Ulalaca") -> ULLogger {
    return OSLog(subsystem: subsystem, category: tag)
}
