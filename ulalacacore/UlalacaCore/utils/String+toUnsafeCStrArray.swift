//
// Created by Gyuhwan Park on 2022/06/29.
//

import Foundation

public extension String {
    func toUnsafeCStrArray<T>(_ __dstPtr: UnsafeMutablePointer<T>, capacity: Int) {
        var srcString = self.cString(using: .utf8)

        var dstPtr = __dstPtr.withMemoryRebound(to: CChar.self, capacity: capacity) { $0 }
        var srcPtr = srcString?.withUnsafeBufferPointer { $0 }

        strncpy(dstPtr, srcPtr?.baseAddress, capacity)
    }
}