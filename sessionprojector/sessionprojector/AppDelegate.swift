//
//  AppDelegate.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2022/04/13.
//
//

import Cocoa
import SwiftUI

import UlalacaCore



@main
struct SessionProjectorApp: App {
    @StateObject
    var appState = AppState.instance
    
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate
    
    
    var body: some Scene {
        WindowGroup("麗 -Ulalaca-: Session Projector") {
            PreferencesWindowView()
                .environmentObject(appState)
        }
        
        MenuBarExtra("SessionProjector Menu", image: "TrayIcon") {
            Button("\(appState.connections) connection(s)") {
                
            }
            .disabled(true)
            
            Divider()
            
            Button("Preferences") {
                appState.showPreferencesWindow()
            }
            .keyboardShortcut(",")
            
            Divider()
            
            Button("About 麗 -Ulalaca-: Session Projector") {
                
            }
            
            Button("Quit") {
                NSApp.terminate(self)
            }
            .keyboardShortcut("q")
            
        }
    }
}

class PreferenceWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(self)
        return false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let logger = createLogger("AppDelegate")

    let screenRecorder = createScreenRecorder()
    let eventInjector = EventInjector()
    let projectionServer = ProjectionServer()
    let sesmanClient = SessionManagerClient()

    var pidLock: PIDLock? = nil

    private let preferenceWindowDelegate = PreferenceWindowDelegate()
    
    private func initializeApp() {
        if let preferenceWindow = NSApp.windows.first {
            preferenceWindow.delegate = self.preferenceWindowDelegate
            preferenceWindow.setContentSize(NSSize(width: 640, height: 480))
        }
        
        NSApp.hide(self)

        if (isLoginSession()) {
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
        } else {
            do {
                pidLock = try PIDLock.acquire(Bundle.main.bundleIdentifier!)
                logger.info("acquired process lock")
            } catch {
                logger.error("failed to acquire process lock: is another instance running?")
                NSApp.terminate(self)
            }
        }

        projectionServer.delegate = self
        sesmanClient.delegate = self
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        self.initializeApp()
        
        Task {
            await startProjectionServer()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        pidLock = nil
        stopProjectionServer()
    }


    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func startProjectionServer() async {
        do {
            try eventInjector.prepare()
            try await screenRecorder.prepare()
            try await screenRecorder.start()

            try sesmanClient.start()
            projectionServer.start()
        } catch {
            print(error.localizedDescription)

            let errorDialog = await NSAlert(error: error)
            await errorDialog.runModal()

            quitApplication()
        }
    }
    
    func stopProjectionServer() {
        sesmanClient.announceSelf(
                ANNOUNCEMENT_TYPE_SESSION_WILL_BE_DESTROYED,
                endpoint: projectionServer.getSocketPath(),
                isConsoleSession: true
        )
        
        // sesmanClient.stop()
        
        projectionServer.stop()
    }

    @objc
    func quitApplication() {
        NSApp.terminate(self)
    }
    
}

extension AppDelegate: ProjectionServerDelegate {
    func projectionServer(sessionInitiated session: ProjectionSession, id: UInt64) {
        screenRecorder.subscribeUpdate(session)
        session.eventInjector = eventInjector
        
        AppState.instance.connections += 1
        
    }

    func projectionServer(sessionClosed session: ProjectionSession, id: UInt64) {
        screenRecorder.unsubscribeUpdate(session)
        session.eventInjector = nil
        
        AppState.instance.connections -= 1
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
