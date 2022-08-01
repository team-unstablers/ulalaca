//
// Created by Gyuhwan Park on 2022/08/01.
//

import Foundation

extension ULIPCRect {
    func scale(x sx: Double, y sy: Double) -> ULIPCRect {
        return ULIPCRect(
            x: Int16(Double(x) * sx),
            y: Int16(Double(y) * sy),
            width: Int16(Double(width) * sx),
            height: Int16(Double(height) * sy)
        )
    }
}