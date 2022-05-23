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

    let screenRecorder = ScreenRecorder()
    let eventInjector = EventInjector()
    let projectionServer = ProjectionServer()

    lazy var trayStatusIndicator = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    lazy var trayMenu: NSMenu = {
        let menu = NSMenu()

        menu.addItem(trayStatusIndicator)
        menu.addItem(withTitle: "Quit", action: #selector(quitApplication), keyEquivalent: "q")

        return menu
    }()

    let trayItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        projectionServer.delegate = self

        initializeTrayItem()
        updateTrayStatusIndicator()

        startProjectionServer()
    }


    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func startProjectionServer() {
        Task {
            do {
                try eventInjector.prepare()
                try await screenRecorder.prepare()
                try await screenRecorder.start()

                projectionServer.start()
            } catch {
                print(error.localizedDescription)

                let errorDialog = await NSAlert(error: error)
                await errorDialog.runModal()

                quitApplication()
            }

        }
    }

    func destroyProjectionServer() {

    }

    @objc
    func quitApplication() {
        destroyProjectionServer()

        NSApp.terminate(self)
    }

    func initializeTrayItem() {
        trayItem.menu = trayMenu
        trayItem.button?.image = NSImage(named: "TrayIcon")
    }

    func updateTrayStatusIndicator() {
        trayStatusIndicator.title = "\(projectionServer.sessions.count) connection(s)"
    }
}

extension AppDelegate: ProjectionServerDelegate {
    func projectionServer(sessionInitiated session: ProjectionSession, id: UInt64) {
        screenRecorder.subscribeUpdate(session)
        session.eventInjector = eventInjector

        updateTrayStatusIndicator()
    }

    func projectionServer(sessionClosed session: ProjectionSession, id: UInt64) {
        screenRecorder.unsubscribeUpdate(session)
        session.eventInjector = nil

        updateTrayStatusIndicator()
    }
}
