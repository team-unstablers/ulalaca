//
// Created by Gyuhwan Park on 2022/05/23.
//

import Foundation

class CStructHolder<T> {
    let size: Int
    fileprivate(set) public var buffer: UnsafeMutableRawPointer

    init() {
        let size = MemoryLayout<T>.size
        let alignment = MemoryLayout<T>.alignment

        self.size = size
        self.buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: alignment)
    }

    deinit {
        buffer.deallocate()
    }

    func getCopy() -> T? {
        return buffer.load(as: T.self)
    }
}

public extension MMUnixSocketBase {
    func readCStruct<T>(_: T.Type) throws -> T? {
        var holder = CStructHolder<T>()
        let bytesRead = try readEx(holder.buffer, size: holder.size)

        if (bytesRead != holder.size) {
            return nil
        }

        return holder.getCopy()
    }
}