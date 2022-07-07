//
// Created by Gyuhwan Park on 2022/07/07.
//

import Foundation

/**
 determines current user is root (loginwindow).
 */
public func isLoginSession() -> Bool {
    return getuid() == 0
}
