//
//  MMUnixSocket+readEx.swift
//  UlalacaCore
//
//  Created by Gyuhwan Park on 2022/05/23.
//

import Foundation

public extension MMUnixSocketBase {
    func readEx(_ buffer: UnsafeMutableRawPointer, size: Int) throws -> Int {
        let bytesRead = read(buffer, size: size)

        if (bytesRead <= 0) {
            throw MMUnixSocketError.socketClosed
        }

        return bytesRead
    }

    func write(_ data: Data) {
        data.withUnsafeBytes { ptr in
            self.write(UnsafeRawPointer(ptr)!, size: data.count)
        }
    }
}

