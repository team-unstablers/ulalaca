//
//  AppMain.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2023/02/10.
//

import Foundation
import SwiftUI

@main
struct SessionProjectLauncherApp: App {
    
    @NSApplicationDelegateAdaptor(LauncherAppDelegate.self)
    private var appDelegate
    
    var body: some Scene {
        WindowGroup {}
    }
}


class LauncherAppDelegate: NSObject, NSApplicationDelegate {
    func createScript() -> NSAppleScript {
        return NSAppleScript(
            source:
"""
do shell script "open -n -W /Applications/sessionprojector.app"
"""
        )!
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.hide(nil)

        let script = createScript()
        
        DispatchQueue.global(qos: .background).async {
            script.executeAndReturnError(nil)
        }
    }

}
