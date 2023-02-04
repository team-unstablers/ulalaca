//
// Created by Gyuhwan Park on 2023/01/30.
//

import Foundation

import UlalacaCore

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
class PowerAssertion {
    private let logger = createLogger("PowerAssertion")

    public let type: PowerAssertionType
    public let timeout: Int?

    private var caffeinateProcess: Process? = nil

    init(for type: PowerAssertionType, timeout: Int? = nil) {
        self.type = type
        self.timeout = timeout
    }

    deinit {
        release()
    }

    private func createFlags() -> Array<String> {
        var flags: Array<String> = []

        flags.append(type.asCaffeinateFlag())

        if let timeout = timeout {
            flags.append("-t")
            flags.append(String(timeout))
        }

        return flags
    }

    func create() throws {
        logger.info("creating power assertion: \(createFlags())")

        let caffeinatePath = URL(fileURLWithPath: "/usr/bin/caffeinate")
        self.caffeinateProcess = try Process.run(caffeinatePath, arguments: createFlags())
    }

    func release() {
        guard let caffeinateProcess = self.caffeinateProcess else {
            return
        }

        logger.info("releasing power assertion")
        caffeinateProcess.terminate()
    }
}