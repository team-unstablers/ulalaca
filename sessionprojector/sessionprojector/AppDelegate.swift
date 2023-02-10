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
                appState.showAboutAppWindow()
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

    var screenRecorder: ScreenRecorder? = nil
    let eventInjector = EventInjector()
    let projectionServer = ProjectionServer()
    let sesmanClient = SessionManagerClient()

    let screenLockObserver = ScreenLockObserver()

    var pidLock: PIDLock? = nil

    var appState: AppState {
        get {
            return AppState.instance
        }
    }

    private let preferenceWindowDelegate = PreferenceWindowDelegate()
    
    private func initializeApp() {
        if let preferenceWindow = NSApp.windows.first {
            preferenceWindow.delegate = self.preferenceWindowDelegate
            preferenceWindow.setContentSize(NSSize(width: 640, height: 480))
            preferenceWindow.setIsVisible(false)
        }

        if (!isLoginSession()) {
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
        screenLockObserver.delegate = self
    }

    /**
     initializes screen recorder
     */
    private func initializeScreenRecorder() async {
        let preferredType = appState
                .userPreferences
                .primaryScreenRecorder

        let screenRecorder = createScreenRecorder(
            preferred: preferredType,
            isScreenLocked: appState.isScreenLocked,
            isLoginSession: isLoginSession()
        )

        screenRecorder.delegate = self

        if let prevScreenRecorder = self.screenRecorder {
            prevScreenRecorder.moveSubscribers(to: screenRecorder)
            await destroyScreenRecorder()
        }

        self.screenRecorder = screenRecorder
    }

    /**
     destroy screen recorder
     */
    private func destroyScreenRecorder() async {
        if (self.screenRecorder == nil) {
            logger.error("destroyScreenRecorder(): screenRecorder is null")
            return
        }

        try? await stopScreenRecorder()
        self.screenRecorder = nil
    }

    private func startScreenRecorder() async throws {
        guard let screenRecorder = self.screenRecorder else {
            logger.error("startScreenRecorder(): screenRecorder is null")
            return
        }

        try await screenRecorder.prepare()
        try await screenRecorder.start()
    }

    private func stopScreenRecorder() async throws {
        guard let screenRecorder = self.screenRecorder else {
            logger.error("startScreenRecorder(): screenRecorder is null")
            return
        }

        try await screenRecorder.stop()
    }

    private func resetScreenRecorder() {

    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        initializeApp()
        
        Task {
            await initializeScreenRecorder()

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

            try await startScreenRecorder()
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
        screenRecorder?.subscribeUpdate(session)
        session.eventInjector = eventInjector
        
        AppState.instance.connections += 1
        
    }

    func projectionServer(sessionClosed session: ProjectionSession, id: UInt64) {
        screenRecorder?.unsubscribeUpdate(session)
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

extension AppDelegate: ScreenRecorderDelegate {
    func screenRecorder(didStopWithError error: Error) {
        // TODO: restart screen recorder
    }
}

extension AppDelegate: ScreenLockObserverDelegate {
    func screenIsLocked() {
        logger.debug("screen locked")
        appState.isScreenLocked = true

        // FIXME: mutex
        Task {
            await initializeScreenRecorder()
            try? await startScreenRecorder()
        }
    }

    func screenIsUnlocked() {
        logger.debug("screen unlocked")
        appState.isScreenLocked = false

        // FIXME: mutex
        Task {
            await initializeScreenRecorder()
            try? await startScreenRecorder()
        }
    }
}
