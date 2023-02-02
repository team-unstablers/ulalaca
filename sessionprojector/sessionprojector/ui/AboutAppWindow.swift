//
//  AboutAppWindow.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2023/02/02.
//

import Foundation
import Cocoa
import SwiftUI

class AboutAppWindow: NSWindow {
    var _delegate: AboutAppWindowDelegate!
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.closable, .titled],
            backing: .buffered,
            defer: false
        )
        
        self.makeKeyAndOrderFront(nil)
        self.isReleasedWhenClosed = false
        self.setIsVisible(false)
        
        self._delegate = AboutAppWindowDelegate(self)
        self.delegate = _delegate
        
        self.title = "About 麗 -Ulalaca-: Session Projector"
        
        self.contentView = NSHostingView(rootView: AboutAppWindowView())
    }
    
    func show() {
        let screens = NSScreen.screens
        let defaultScreen = screens.first!
        let pos = NSPoint(
            x: defaultScreen.visibleFrame.midX - 200,
            y: defaultScreen.visibleFrame.midY + 100
        )
        self.setFrameOrigin(pos)
        
        self.setIsVisible(true)
    }
    
    func hide() {
        self.setIsVisible(false)
    }
}

class AboutAppWindowDelegate: NSObject, NSWindowDelegate {
    var window: AboutAppWindow!
    
    init(_ window: AboutAppWindow) {
        super.init()
        self.window = window
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        self.window.hide()
        return false
    }
}
