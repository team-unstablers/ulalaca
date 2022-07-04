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

    let screenRecorder = createScreenRecorder()
    let eventInjector = EventInjector()
    let projectionServer = ProjectionServer()
    let sesmanClient = ProjectorManagerClient()

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
        sesmanClient.delegate = self

        if (getuid() != 0) {
            // FIXME!!
            initializeTrayItem()
            updateTrayStatusIndicator()
        }
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

                sesmanClient.start()
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
        sesmanClient.announceSelf(
                ANNOUNCEMENT_TYPE_SESSION_WILL_BE_DESTROYED,
                endpoint: projectionServer.getSocketPath(),
                isConsoleSession: true
        )
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

extension AppDelegate: IPCClientDelegate {
    func connected() {
        sesmanClient.announceSelf(
                ANNOUNCEMENT_TYPE_SESSION_CREATED,
                endpoint: projectionServer.getSocketPath(),
                isConsoleSession: true
        )
    }

    func received(header: ULIPCHeader) {
    }

    func disconnected() {
    }
}
