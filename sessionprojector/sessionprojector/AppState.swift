//
//  AppState.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2023/01/25.
//

import Foundation
import Cocoa

enum ScreenRecorderType: String, Identifiable, CaseIterable, Codable {
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
    
    case avfScreenRecorder = "avfScreenRecorder"
    case scScreenRecorder  = "scScreenRecorder"
}

protocol BasePreferences: ObservableObject, Codable {
    init()
    init(from decoder: Decoder) throws
    func encode(to encoder: Encoder) throws
}

func loadPreferences<T>(from path: String, is type: T.Type) -> T where T: BasePreferences {
    let fileManager = FileManager.default
    let url = URL(filePath: path)
    
    if (!fileManager.fileExists(atPath: path)) {
        return T()
    }
    
    do {
        let json = try Data(contentsOf: url)
        let instance: T = try JSONDecoder().decode(type, from: json)
        
        return instance
    } catch {
        print(error.localizedDescription)
    }
    
    return T()
}

func savePreferences<T>(_ preferences: T, to path: String) throws where T: BasePreferences {
    guard let data = try preferences.toJSON().data(using: .utf8) else {
        return
    }
    let url = URL(filePath: path)
    
    try data.write(to: url)
}

class GlobalPreferences: NSObject, BasePreferences {
    enum CodingKeys: String, CodingKey {
        case launchOnLoginwindow = "launchOnLoginWindow"
        case launchOnUserLogin = "launchOnUserLogin"
    }
    
    @Published
    var launchOnLoginwindow: Bool = true
    
    @Published
    var launchOnUserLogin: Bool = true
    
    override required init() {
        super.init()
    }
    
    required init(from decoder: Decoder) throws {
        super.init()
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        launchOnLoginwindow = try container.decode(Bool.self, forKey: .launchOnLoginwindow)
        launchOnUserLogin = try container.decode(Bool.self, forKey: .launchOnUserLogin)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(launchOnLoginwindow, forKey: .launchOnLoginwindow)
        try container.encode(launchOnUserLogin, forKey: .launchOnUserLogin)
    }
}

class UserPreferences: NSObject, BasePreferences {
    enum CodingKeys: String, CodingKey {
        case primaryScreenRecorder = "primaryScreenRecorder"
        case autoFramerate = "autoFramerate"
        case framerate = "framerate"
    }
    
    @Published
    var primaryScreenRecorder: ScreenRecorderType = .scScreenRecorder
    
    @Published
    var autoFramerate: Bool = true

    @Published
    var framerate: Float = 60
    
    
    override required init() {
        super.init()
    }
    
    required init(from decoder: Decoder) throws {
        super.init()
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        primaryScreenRecorder = try container.decode(ScreenRecorderType.self, forKey: .primaryScreenRecorder)
        autoFramerate = try container.decode(Bool.self, forKey: .autoFramerate)
        framerate = try container.decode(Float.self, forKey: .framerate)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(primaryScreenRecorder, forKey: .primaryScreenRecorder)
        try container.encode(autoFramerate, forKey: .autoFramerate)
        try container.encode(framerate, forKey: .framerate)
    }
}

class AppState: NSObject, ObservableObject {
    static let instance = AppState()
    
    @Published
    var globalPreferences: GlobalPreferences
    
    @Published
    var userPreferences: UserPreferences

    @Published
    var connections: Int = 0
    
    
    var preferencesWindow: NSWindow {
        get {
            NSApp.windows.first!
        }
    }
    
    var aboutAppWindow: AboutAppWindow? = nil
    
    
    override init() {
        let fileManager = FileManager.default
        let userPreferencesPath = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".sessionprojector.json")
        
        globalPreferences = loadPreferences(from: "/etc/ulalaca/sessionprojector.json", is: GlobalPreferences.self)
        userPreferences   = loadPreferences(from: userPreferencesPath.path(percentEncoded: false),   is: UserPreferences.self)
        
        super.init()
    }
    
    func savePreferences() {
        let fileManager = FileManager.default
        let userPreferencesPath = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".sessionprojector.json")
        
        try? sessionprojector.savePreferences(userPreferences, to: userPreferencesPath.path(percentEncoded: false))
    }
    
    func showPreferencesWindow() {
        preferencesWindow.setIsVisible(true)
        preferencesWindow.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hidePreferencesWindow() {
        preferencesWindow.setIsVisible(false)
    }
    
    func showAboutAppWindow() {
        guard let aboutAppWindow = aboutAppWindow else {
            aboutAppWindow = AboutAppWindow()
            showAboutAppWindow()
            return
        }
        
        aboutAppWindow.show()
        aboutAppWindow.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }
}
