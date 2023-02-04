//
// Created by Gyuhwan Park on 2023/01/30.
//

import Foundation


enum PowerAssertionType {
    case preventUserIdleSystemSleep
    case preventUserIdleDisplaySleep
    case preventSystemSleep
    // case noIdleSleep
    // case noDisplaySleep

    func asCaffeinateFlag() -> String {
        switch (self) {
        case .preventUserIdleSystemSleep:
            return "-i"

        case .preventUserIdleDisplaySleep:
            return "-d"

        case .preventSystemSleep:
            return "-s"
        }
    }
}

/**
 wrapper class of system("caffeinate")

 TODO: use IOPMAssertionCreate* instead of system("caffeinate")
 */
class PowerAssertionManager {
    private func createCaffeinateScript(for type: PowerAssertionType, timeout: Int? = nil) -> NSAppleScript? {
        var timeoutFlag = ""

        if let timeout = timeout {
            timeoutFlag = "-t \(String(timeout))"
        }

        return NSAppleScript(source: """
            do shell script "/usr/bin/caffeinate \(type.asCaffeinateFlag()) \(timeoutFlag)"
        """)
    }

    func createAssertion(for type: PowerAssertionType, timeout: Int? = nil) {
        guard let appleScript = createCaffeinateScript(for: type, timeout: timeout) else {
            // logger.warn("could not create assertion for type \(type)")
            return
        }

        appleScript.executeAndReturnError(nil)
    }
}