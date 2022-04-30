//
//  AppDelegate.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2022/04/13.
//
//

import Cocoa


@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!

    var screenRecorder = ScreenRecorder()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        Task {
            try! await screenRecorder.prepare()
            try! await screenRecorder.start()
        }
    }


    func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
    }


    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
