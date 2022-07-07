//
//  AppDelegate.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2022/04/13.
//
//

import Cocoa

import UlalacaCore

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let screenRecorder = createScreenRecorder()
    let eventInjector = EventInjector()
    let projectionServer = ProjectionServer()
    let sesmanClient = SessionManagerClient()

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

        // FIXME
        let processInfo = ProcessInfo.processInfo
        if (processInfo.arguments.first { $0 == "--launch" } != nil) {
            sleep(3)
            try! Process.run(URL(fileURLWithPath: "/usr/bin/osascript"), arguments: [
                "-e",
                "do shell script \"open -n -W /Library/PrivilegedHelperTools/sessionprojector.app\""
            ]) { _ in
                NSApp.terminate(self)
            }
            return;
        }

        projectionServer.delegate = self
        sesmanClient.delegate = self

        if (!isLoginSession()) {
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
                isConsoleSession: true, // FIXME
                isLoginSession: isLoginSession()
        )
    }

    func received(header: ULIPCHeader) {
    }

    func disconnected() {
    }
}
