//
// Created by Gyuhwan Park on 2022/05/23.
//

import os

import Foundation

public enum ULGlobalLoggerLevel {
    case verbose
    case normal
    case quiet

    func shouldWriteLog(with level: String) -> Bool {
        if (self == .verbose) {
            return true
        }

        if (self == .normal) {
            return level != "DEBUG"
        }

        return false
    }
}

public protocol ULLogger {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
    func fatal(_ message: String)
}

var UL_GLOBAL_LOG_LEVEL: ULGlobalLoggerLevel = .normal

public func setGlobalLoggerLevel(_ level: ULGlobalLoggerLevel) {
    UL_GLOBAL_LOG_LEVEL = level
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
        if (!UL_GLOBAL_LOG_LEVEL.shouldWriteLog(with: level)) {
            return;
        }

        fputs("[\(now)][\(tag):\(level)] \(message)\n", stderr)
    }

    public func debug(_ message: String) {
        write(level: "DEBUG", tag: tag, message: message)
    }

    public func info(_ message: String) {
        write(level: "INFO", tag: tag, message: message)
    }

    public func warning(_ message: String) {
        write(level: "WARNING", tag: tag, message: message)
    }

    public func error(_ message: String) {
        write(level: "ERROR", tag: tag, message: message)
    }

    public func fatal(_ message: String) {
        write(level: "FATAL", tag: tag, message: message)
    }
}

extension OSLog: ULLogger {
    func ul_log(level: String, type: OSLogType, message: String) {
        if (!UL_GLOBAL_LOG_LEVEL.shouldWriteLog(with: level)) {
            return;
        }

        os_log("[%@] %@", log: self, type: type, level, message)
    }

    public func debug(_ message: String) {
        ul_log(level: "DEBUG", type: .debug, message: message)
    }

    public func info(_ message: String) {
        ul_log(level: "INFO", type: .info, message: message)
    }

    public func warning(_ message: String) {
        ul_log(level: "WARNING", type: .default, message: message)
    }

    public func error(_ message: String) {
        ul_log(level: "ERROR", type: .error, message: message)
    }

    public func fatal(_ message: String) {
        ul_log(level: "FATAL", type: .fault, message: message)
    }
}

class MuxedLogger: ULLogger {

    private let subsystem: String
    private let tag: String

    private var impls: Array<ULLogger> = []

    init(tag: String, subsystem: String) {
        self.subsystem = subsystem
        self.tag = tag

        impls.append(createOSLogger(tag, subsystem: subsystem))
        impls.append(createLogger(tag, subsystem: subsystem))
    }

    public func debug(_ message: String) {
        impls.forEach { $0.debug(message) }
    }

    public func info(_ message: String) {
        impls.forEach { $0.info(message) }
    }

    public func warning(_ message: String) {
        impls.forEach { $0.warning(message) }
    }

    public func error(_ message: String) {
        impls.forEach { $0.error(message) }
    }

    public func fatal(_ message: String) {
        impls.forEach { $0.fatal(message) }
    }
}

public func createLogger(_ tag: String, subsystem: String = "Ulalaca") -> ULConsoleLogger {
    return ULConsoleLogger(tag: tag, subsystem: subsystem)
}

public func createOSLogger(_ tag: String, subsystem: String = "Ulalaca") -> ULLogger {
    return OSLog(subsystem: subsystem, category: tag)
}

public func createMuxedLogger(_ tag: String, subsystem: String = "Ulalaca") -> ULLogger {
    return MuxedLogger(tag: tag, subsystem: subsystem)
}