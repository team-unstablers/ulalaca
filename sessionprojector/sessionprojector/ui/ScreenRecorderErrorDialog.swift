//
// Created by Gyuhwan Park on 2023/06/04.
//

import Foundation
import Cocoa
import SwiftUI


enum ScreenRecorderErrorDialogResult {
    case openSystemPreferences
    case quitApp
    case ignore
}

class ScreenRecorderErrorDialog: NSAlert {
    var error: ScreenRecorderError = .unknown

    var openSystemPreferencesButton: NSButton!
    var quitAppButton: NSButton!
    var ignoreButton: NSButton!


    init(what error: ScreenRecorderError) {
        self.error = error

        super.init()

        self.messageText = "Cannot start screen recording."
        self.informativeText = error.localizedDescription

        self.alertStyle = .critical

        self.openSystemPreferencesButton = self.addButton(withTitle: "Open System Preferences")
        self.quitAppButton = self.addButton(withTitle: "Quit Application")
        self.ignoreButton = self.addButton(withTitle: "Ignore")
    }

    func show() -> ScreenRecorderErrorDialogResult {
        let result = self.runModal()

        switch (result) {
        case .alertFirstButtonReturn:
            return .openSystemPreferences
        case .alertSecondButtonReturn:
            return .quitApp
        case .alertThirdButtonReturn:
            return .ignore
        default:
            return .ignore
        }
    }
}