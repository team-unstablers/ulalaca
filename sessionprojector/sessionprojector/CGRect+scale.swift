//
// Created by Gyuhwan Park on 2023/06/28.
//

import Foundation

extension CGRect {
    func scale(sx: CGFloat, sy: CGFloat) -> CGRect {
        return CGRect(
            x: origin.x * sx,
            y: origin.y * sy,
            width: size.width * sx,
            height: size.height * sy
        )
    }

    func scale(by scaleFactor: CGFloat) -> CGRect {
        return scale(sx: scaleFactor, sy: scaleFactor)
    }
}