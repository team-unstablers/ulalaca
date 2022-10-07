//
//  IPCServerBaseTest.swift
//  UlalacaCoreTests
//
//  Created by Gyuhwan Park on 2022/10/07.
//

import XCTest
import UlalacaCore

class MockedIPCServer: IPCServerBase {
    init(_ option: MockedMMUnixSocketOption, maxClients: Int) {
        super.init(with: MockedMMUnixSocket(option, maxClients: maxClients), path: "/tmp/ulalaca-ipc-test.sock")
    }
}

final class IPCServerBaseTest: XCTestCase {

    private var clients: Array<IPCServerConnection> = []

    override func setUpWithError() throws {
        clients.removeAll()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testIPCServerCase1() throws {
        let server = MockedIPCServer([.readWillFail, .writeWillFail], maxClients: 1)
        server.delegate = self

        let serverTask = Task {
            server.start()
        }
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.

        while (clients.isEmpty) {
            sleep(1)
        }

        XCTAssertThrowsError(try clients[0].read(ULIPCSessionRequest.self))
        XCTAssertThrowsError(
            try clients[0].writeMessage(ULIPCSessionRequestRejected(
                reason: REJECT_REASON_AUTHENTICATION_FAILED
            ), type: TYPE_SESSION_REQUEST_REJECTED)
        )

        server.stop()
        serverTask.cancel()
    }

    func testIPCServerCase2() throws {
        let server = MockedIPCServer([], maxClients: 1)
        server.delegate = self

        let serverTask = Task {
            server.start()
        }
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.

        while (clients.isEmpty) {
            sleep(1)
        }

        XCTAssertNoThrow(try clients[0].read(ULIPCSessionRequest.self))
        XCTAssertNoThrow(
            try clients[0].writeMessage(ULIPCSessionRequestRejected(
                    reason: REJECT_REASON_AUTHENTICATION_FAILED
            ), type: TYPE_SESSION_REQUEST_REJECTED)
        )

        server.stop()
        serverTask.cancel()
    }

}

extension IPCServerBaseTest: IPCServerDelegate {
    func connectionEstablished(with client: UlalacaCore.IPCServerConnection) {
        clients.append(client)
    }

    func received(header: ULIPCHeader, from client: UlalacaCore.IPCServerConnection) {
    }

    func connectionClosed(with client: UlalacaCore.IPCServerConnection) {
    }
}