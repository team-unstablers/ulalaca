//
//  AppDelegate.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2022/04/13.
//
//

import Cocoa
import SwiftUI

import UserNotifications

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
            Button("Stop Projection") {
                // TODO: stop projection
            }

            Divider()


            Button("\(appState.connections.count) connection(s)") {
                
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

    var userNotificationCenter: UNUserNotificationCenter {
        get {
            return UNUserNotificationCenter.current()
        }
    }

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
        setGlobalLoggerLevel(.verbose)

        if let preferenceWindow = NSApp.windows.first {
            preferenceWindow.delegate = self.preferenceWindowDelegate
            preferenceWindow.setContentSize(NSSize(width: 640, height: 480))
            preferenceWindow.setIsVisible(false)
        }

        if (!isLoginSession()) {
            do {
                pidLock = try PIDLock.acquire(Bundle.main.bundleIdentifier!)
                logger.info("acquired process lock")
            } catch let error as PIDLockError {
                logger.error("failed to acquire process lock: is another instance running?")
                let result = PIDLockErrorDialog(what: error).show()

                switch (result) {
                case .killPrevInstance:
                    logger.info("killing previous instance (pid #\(error.pid!)) with SIGTERM...")
                    kill(error.pid!, SIGTERM)
                    break
                case .quitApp:
                    NSApp.terminate(self)
                    break
                case .ignore:
                    break
                }
            } catch {
                logger.error("failed to acquire process lock: unknown error")
                NSApp.terminate(self)
            }
        }

        projectionServer.delegate = self
        sesmanClient.delegate = self
        screenLockObserver.delegate = self

        appState.isScreenLocked = CGSessionUtil.isScreenLocked()
        screenLockObserver.startObserve()
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


        do {
            try await screenRecorder.prepare()
            try await screenRecorder.start()
        } catch let error as ScreenRecorderError {
            let errorDialog = await ScreenRecorderErrorDialog(what: error)
            let result = await errorDialog.show()

            switch (result) {
            case .openSystemPreferences:
                // @copilot Open system preferences / security & privacy / privacy / screen recording
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                break
            case .quitApp:
                await NSApp.terminate(self)
                break
            case .ignore:
                break
            }
        }
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
            try projectionServer.start()
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

    func postUserNotificationSync(title: String, message: String, identifier: UUID = UUID()) {
        Task {
            await postUserNotification(title: title, message: message, identifier: identifier)
        }
    }

    func postUserNotification(title: String, message: String, identifier: UUID = UUID()) async {
        logger.debug("posting user notification: [\(title)] \(message)")
        guard let granted = try? await userNotificationCenter.requestAuthorization(options: [.alert, .sound]) else {
            logger.error("postUserNotification: cannot request authorization for user notification")
            return
        }

        if (!granted) {
            logger.error("postUserNotification: user notification is not granted")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message

        let request = UNNotificationRequest(
                identifier: identifier.uuidString,
                content: content,
                trigger: nil
        )

        do {
            try await userNotificationCenter.add(request)
        } catch {
            logger.error("postUserNotification: failed to post user notification: \(error.localizedDescription)")
        }
    }
}

extension AppDelegate: ProjectionServerDelegate {
    func projectionServer(sessionInitiated session: ProjectionSession, id: UInt64) {
        screenRecorder?.subscribeUpdate(session)
        session.eventInjector = eventInjector
        
        AppState.instance.connections.insert(session)

        let clientInfo = session.clientInfo
        
        postUserNotificationSync(
                title: "New connection",
                message: (AppState.instance.connections.count > 1) ?
                    "A new connection has been established from \(clientInfo.clientAddress).\nThe content of this session being shared with \(AppState.instance.connections.count) remote clients." :
                    "A new connection has been established from \(clientInfo.clientAddress).\nThe content of this session will be shared with the remote client."
        )
    }

    func projectionServer(sessionClosed session: ProjectionSession, id: UInt64) {
        let clientInfo = session.clientInfo
        
        screenRecorder?.unsubscribeUpdate(session)
        session.eventInjector = nil
        
        AppState.instance.connections.remove(session)

        postUserNotificationSync(
                title: "Connection closed",
                message: (AppState.instance.connections.count > 0) ?
                    "Connection has been closed from \(clientInfo.clientAddress).\n\(AppState.instance.connections.count) remote clients are still connected." :
                    "Connection has been closed from \(clientInfo.clientAddress)."
        )
    }
}

extension AppDelegate: IPCClientDelegate {
    func connected() {
        logger.info("connected to sessionbroker. this graphical session will be announced as available to other clients.")
        sesmanClient.announceSelf(
                ANNOUNCEMENT_TYPE_SESSION_CREATED,
                endpoint: projectionServer.getSocketPath(),
                isConsoleSession: true, // FIXME
                isLoginSession: isLoginSession()
        )
    }

    func received(header: ULIPCHeader) {
        logger.info("received header \(header.messageType) from sessionbroker")
        logger.debug("... but not implemented yet.")
    }

    func disconnected() {
        logger.info("disconnected from sessionbroker")
        postUserNotificationSync(
            title: "sessionbroker: Connection lost",
            message: "The connection to sessionbroker has been lost.\nConnection will be re-established automatically after 15 seconds."
        )

        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 15) {
            self.sesmanClient.start()
        }
    }

    func error(what error: Error?) {
        let message = error?.localizedDescription ?? "Unknown error."

        logger.info("sessionbroker connection error: \(message)")

        postUserNotificationSync(
            title: "sessionbroker: Connection error",
            message: "\(message)\nConnection will be re-established automatically after 15 seconds."
        )

        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 15) {
            self.sesmanClient.start()
        }
    }
}

extension AppDelegate: ScreenRecorderDelegate {
    func screenRecorder(didStopWithError error: Error) {
        // TODO: restart screen recorder
        logger.error("screen recorder stopped with error: \(error.localizedDescription)")
    }
}

extension AppDelegate: ScreenLockObserverDelegate {
    func screenIsLocked() {
        logger.debug("screen locked")
        appState.isScreenLocked = true

        // FIXME: mutex
        // should i use rxswift to observe appState.isScreenLocked?
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
