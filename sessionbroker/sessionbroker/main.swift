//
//  main.swift
//  sessionbroker
//
//  Created by Gyuhwan Park on 2022/05/16.
//

import Foundation

import UlalacaCore

class SessionBrokerDaemon {
    enum CLIArgument: String {
        case verbose = "--verbose"

        case help = "--help"
        case version = "--version"
    }

    let logger = createLogger("sessionbroker")

    let sesman = SessionManagerServer()
    let broker = SessionBrokerServer()

    init() {
    }

    func setup(_ argv: [String]) {
        var args: Array<CLIArgument> = []

        for arg in argv[1...] {
            guard let cliArg = CLIArgument(rawValue: arg) else {
                logger.error("Unknown argument: \(arg)")
                displayHelp()
                exit(2)
            }

            args.append(cliArg)
        }

        for arg in args {
            switch (arg) {
            case .verbose:
                setGlobalLoggerLevel(ULGlobalLoggerLevel.verbose)
                break
            case .help:
                displayHelp()
                exit(0)
                break
            case .version:
                displayVersion(withAdvertisement: true)
                exit(0)
                break
            default:
                break
            }
        }

        // setupSignalHandlers()

        if (getuid() != 0) {
            logger.warning("sessionbroker should be run as root. Continuing anyway..")
        }
    }

    func displayHelp() {
        let message =
            """
            NAME
                sessionbroker - session broker daemon for \(UlalacaProductName())

            USAGE
                sessionbroker [options]

            OPTIONS
                --verbose
                    Enable verbose logging.

                --help
                    Display this help message.

                --version
                    Display version information.

            """

        fputs(message, stderr)
    }

    func displayVersion(withAdvertisement: Bool) {
        let message =
            """
            \(UlalacaProductName()): sessionbroker version \(UlalacaVersion())

            This software is open source software licensed under the Apache License 2.0.
            You may obtain a copy of the source code for this software at https://github.com/team-unstablers/Ulalaca

            (c) 2022-2023 team unstablers Inc.
                https://unstabler.pl\n\n
            """

        fputs(message, stderr)

        if (!withAdvertisement) {
            return
        }

        let ANSI_RESET = "\u{001B}[0m"
        let ANSI_BOLD = "\u{001B}[1m"
        let ANSI_BLINK = "\u{001B}[5m"

        fputs(ANSI_BOLD + ANSI_BLINK, stderr)
        fputs("\n\n[ADVERTISEMENT]\n", stderr)
        fputs(ANSI_RESET, stderr)

        let advertisement =
        """
        Hello! We are team unstablers, a contract software development team based in South Korea.
        We are currently looking for a new project to work on.

        If you are interested in working with us, please contact us at contact@unstabler.pl.

        Thank you for using our software!\n
        """

        fputs(advertisement, stderr)
    }

    func start() {
        displayVersion(withAdvertisement: false)

        DispatchQueue.global(qos: .default).async {
            self.logger.info("Starting sesman..")

            do {
                try self.sesman.start()
            } catch {
                self.logger.error("Caught error while starting sesman: \(error)")
                exit(1)
            }
        }

        DispatchQueue.global(qos: .default).async {
            self.logger.info("Starting broker..")

            do {
                try self.broker.start()
            } catch {
                self.logger.error("Caught error while starting broker: \(error)")
                exit(1)
            }
        }
    }

    func stop() {
        do {
            logger.info("Stopping sesman..")
            self.sesman.stop()

            logger.info("Stopping broker..")
            self.broker.stop()
        } catch {
            self.logger.error("Caught error while stopping daemon: \(error)")
            exit(1)
        }
    }

}

func main() {
    let daemon = SessionBrokerDaemon()

    daemon.setup(CommandLine.arguments)

    daemon.start()
    dispatchMain()
}

main()