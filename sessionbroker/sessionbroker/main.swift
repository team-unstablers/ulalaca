//
//  main.swift
//  sessionbroker
//
//  Created by Gyuhwan Park on 2022/05/16.
//

import Foundation

func main() {
    let sesman = SessionManagerServer()
    let server = SessionBrokerServer()

    DispatchQueue.global().async {
        print("starting sesman")
        sesman.start()
    }

    print("starting server")
    server.start()
}

main()