//
// Created by Gyuhwan Park on 2022/08/01.
//

import Foundation

extension CGRect {
    func toULIPCRect() -> ULIPCRect {
        return ULIPCRect(
            x: Int16(origin.x),
            y: Int16(origin.y),
            width: Int16(size.width),
            height: Int16(size.height)
        )
    }
}