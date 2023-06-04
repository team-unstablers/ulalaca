//
//  main.swift
//  sessionbroker
//
//  Created by Gyuhwan Park on 2022/05/16.
//

import Foundation

import UlalacaCore

func main() {
    let logger = createLogger("sessionbroker-main")
    let sesman = SessionManagerServer()
    let broker = SessionBrokerServer()

    DispatchQueue.global().async {
        logger.info("Starting server: sesman")
        // FIXME: wrap using do-catch
        try? sesman.start()
    }

    logger.info("Starting server: broker")
    // FIXME: wrap using do-catch
    try? broker.start()
}

main()