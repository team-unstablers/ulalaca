//
//  AppState.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2023/01/25.
//

import Foundation
import Cocoa

enum ScreenRecorderType: Identifiable, CaseIterable {
    var id: Self {
        return self
    }
    var description: String {
        get {
            switch (self) {
            case .avfScreenRecorder:
                return "AVFScreenRecorder (AVFoundation)"
            case .scScreenRecorder:
                return "SCScreenRecorder (ScreenCaptureKit)"
            }
        }
    }
    
    case avfScreenRecorder
    case scScreenRecorder
    
}

class GlobalPreferences: NSObject, ObservableObject {
    @Published
    var launchOnLoginwindow: Bool = true
    
    @Published
    var launchOnUserLogin: Bool = true
}

class AppState: NSObject, ObservableObject {
    @Published
    var globalPreferences = GlobalPreferences()
    
    @Published
    var primaryScreenRecorder: ScreenRecorderType = .scScreenRecorder
    
    
    @Published
    var autoFramerate: Bool = true

    @Published
    var frameRate: Float = 60
    
    @Published
    var connections: Int = 0
    
    
    var preferencesWindow: NSWindow {
        get {
            NSApp.windows.first!
        }
    }
    
    
    func showPreferencesWindow() {
        NSApp.unhide(self)
        preferencesWindow.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hidePreferencesWindow() {
        NSApp.hide(self)
    }
}
