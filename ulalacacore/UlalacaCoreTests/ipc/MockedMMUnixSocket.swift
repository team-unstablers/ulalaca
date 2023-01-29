//
// Created by Gyuhwan Park on 2022/10/07.
//

import Foundation
import UlalacaCore

struct MockedMMUnixSocketOption: OptionSet {
    let rawValue: Int

    static let bindWillFail = MockedMMUnixSocketOption(rawValue: 0b0001)
    static let connectWillFail = MockedMMUnixSocketOption(rawValue: 0b0010)

    static let readWillFail = MockedMMUnixSocketOption(rawValue: 0b0100)
    static let partiallyRead = MockedMMUnixSocketOption(rawValue: 0b1000)

    static let writeWillFail = MockedMMUnixSocketOption(rawValue: 0b010000)
}

class MockedMMUnixSocketConnection: MMUnixSocketConnection {
    private let fd: Int

    public let option: MockedMMUnixSocketOption

    init(_ option: MockedMMUnixSocketOption = []) {
        self.fd = MockedMMUnixSocket.fdCounter
        self.option = option

        MockedMMUnixSocket.fdCounter += 1

        super.init()
    }

    override func descriptor() -> Int32 {
        return Int32(fd)
    }

    override func read(_ buffer: UnsafeMutableRawPointer!, size: Int) -> Int {
        if (option.contains(.readWillFail)) {
            return -1
        }

        if (option.contains(.partiallyRead)) {
            return Int(size / 2)
        } else {
            return size
        }
    }

    override func write(_ buffer: UnsafeRawPointer!, size: Int) -> Int {
        if (option.contains(.writeWillFail)) {
            return -1
        }

        return size
    }

    override func close() {

    }
}

class MockedMMUnixSocket: MMUnixSocket {
    fileprivate static var fdCounter: Int = 1

    private let fd: Int

    public let option: MockedMMUnixSocketOption
    private(set) public var currentClients = 0
    public var maxClients: Int


    init(_ option: MockedMMUnixSocketOption, maxClients: Int) {
        self.fd = MockedMMUnixSocket.fdCounter
        self.option = option
        self.maxClients = maxClients

        MockedMMUnixSocket.fdCounter += 1

        super.init("/tmp/ulalacacore-test.sock")
    }

    override func descriptor() -> Int32 {
        return Int32(fd)
    }

    override func bind() {
        if (option.contains(.bindWillFail)) {
            raiseException("caught SystemCallException: bind() (errno=1)")
        }
    }

    override func listen() {
    }

    override func accept() -> MMUnixSocketConnection! {
        if (currentClients >= maxClients) {
            // block forever
            while (true) {
                sleep(1)
            }
        }

        self.currentClients += 1
        return MockedMMUnixSocketConnection(self.option)
    }

    override func connect() {
        if (option.contains(.connectWillFail)) {
            raiseException("caught SystemCallException: connect() (errno=1)")
        }
    }

    override func read(_ buffer: UnsafeMutableRawPointer!, size: Int) -> Int {
        if (option.contains(.readWillFail)) {
            return -1
        }

        if (option.contains(.partiallyRead)) {
            return Int(size / 2)
        } else {
            return size
        }
    }

    override func write(_ buffer: UnsafeRawPointer!, size: Int) -> Int {
        if (option.contains(.writeWillFail)) {
            return -1
        }

        return size
    }

    override func close() {

    }
}


fileprivate extension MMUnixSocket {
    func raiseException(_ message: String) {
        NSException.raise(
                NSExceptionName(rawValue: "MMUnixSocketException"),
                format: message,
                arguments: getVaList([])
        )
    }
}