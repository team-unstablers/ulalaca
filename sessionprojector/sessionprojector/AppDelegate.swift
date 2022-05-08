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

    let screenRecorder = ScreenRecorder()
    let eventInjector = EventInjector()
    let projectionServer = ProjectionServer()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        projectionServer.delegate = self

        Task {
            do {
                try await screenRecorder.prepare()
                try await screenRecorder.start()
            } catch {
                print(error.localizedDescription)
            }
            
            await window.close()
            projectionServer.start()
        }
    }


    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

extension AppDelegate: ProjectionServerDelegate {
    func projectionServer(sessionInitiated session: ProjectionSession, id: UInt64) {
        screenRecorder.subscribeUpdate(session)
        session.eventInjector = eventInjector
    }

    func projectionServer(sessionClosed id: UInt64) {

    }
}
