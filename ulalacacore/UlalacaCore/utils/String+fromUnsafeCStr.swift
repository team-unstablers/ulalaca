//
// Created by Gyuhwan Park on 2022/05/23.
//

import Foundation

public extension String {
    init(fromUnsafeCStr cStrPtr: UnsafeRawPointer, length: Int) {
        self.init(cString: cStrPtr.bindMemory(to: CChar.self, capacity: length))
    }
}