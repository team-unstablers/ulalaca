//
// Created by Gyuhwan Park on 2023/06/28.
//

import Foundation
import Quartz

/*
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] kCGSSessionUserIDKey: 501
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] kCGSessionLoginDoneKey: 1
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] kCGSSessionOnConsoleKey: 1
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] kCGSessionLongUserNameKey: Gyuhwan Park
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] CGSSessionScreenIsLocked: 1
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] kSCSecuritySessionID: 100015
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] kCGSSessionGroupIDKey: 20
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] kCGSSessionAuditIDKey: 100015
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] kCGSSessionUserNameKey: cheesekun
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] kCGSSessionSystemSafeBoot: 0
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] CGSSessionScreenLockedTime: 1687946429
[2023/06/28 7:00 PM][ScreenLockObserver:DEBUG] kCGSSessionLoginwindowSafeLogin: 0
 */

enum CGSessionDictionaryKey: String {
    case userId = "kCGSSessionUserIDKey"
    case sessionId = "kSCSecuritySessionID"
    case sessionOnConsole = "kCGSSessionOnConsoleKey"

    case screenIsLocked = "CGSSessionScreenIsLocked"
    case screenLockedTime = "CGSSessionScreenLockedTime"
}

class CGSessionUtil {
    static func userId() -> Int? {
        return CGSessionCopyCurrentDictionary()?.value(for: .userId)
    }

    static func sessionId() -> Int? {
        return CGSessionCopyCurrentDictionary()?.value(for: .sessionId)
    }

    static func isSessionOnConsole() -> Bool {
        return CGSessionCopyCurrentDictionary()?.value(for: .sessionOnConsole) == 1
    }

    static func isScreenLocked() -> Bool {
        return CGSessionCopyCurrentDictionary()?.value(for: .screenIsLocked) == 1
    }
}

fileprivate extension CFDictionary {
    func value<T>(for key: CGSessionDictionaryKey) -> T? {
        guard let dict = self as NSDictionary as? [String: Any] else {
            return nil
        }

        return dict[key.rawValue] as? T
    }
}