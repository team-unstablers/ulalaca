//
// Created by Gyuhwan Park on 2023/06/04.
//

import Foundation
import Cocoa
import SwiftUI


enum PIDLockErrorDialogResult {
    case killPrevInstance
    case quitApp
    case ignore
}

class PIDLockErrorDialog: NSAlert {
    var error: PIDLockError!

    init(what error: PIDLockError) {
        self.error = error

        super.init()

        self.messageText = "Failed to acquire process lock."
        self.informativeText = "It seems that another instance is already running.\n\n\(error.localizedDescription)"

        self.alertStyle = .critical

        self.addButton(withTitle: "Quit Application")

        if let pid = error.pid {
            self.addButton(withTitle: "Kill Previous Instance (PID \(String(pid)))")
        }

        self.addButton(withTitle: "Ignore")
    }

    func show() -> PIDLockErrorDialogResult {
        let result = self.runModal()

        switch (result) {
        case .alertFirstButtonReturn:
            return .quitApp
        case .alertSecondButtonReturn:
            return .killPrevInstance
        case .alertThirdButtonReturn:
            return .ignore
        default:
            return .ignore
        }
    }
}