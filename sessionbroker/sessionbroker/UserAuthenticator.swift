//
// Created by Gyuhwan Park on 2022/05/16.
//

import Foundation
import OpenDirectory

class UserAuthenticator {
    /**
     https://developer.apple.com/forums/thread/117924
     */
    func authenticate(_ username: String, with password: String) -> Bool {
        do {
            let session = ODSession()
            let node = try ODNode(session: session, type: ODNodeType(kODNodeTypeLocalNodes))
            let record = try node.record(withRecordType: kODRecordTypeUsers, name: username, attributes: nil)
            try record.verifyPassword(password)

            return true
        } catch {
            return false
        }
    }
}