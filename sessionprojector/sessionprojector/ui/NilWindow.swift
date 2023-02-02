//
//  NilWindow.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2023/02/02.
//

import Foundation
import Cocoa

class NilWindow: NSWindow {
    var _delegate: NilWindowDelegate = NilWindowDelegate()
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.titled, .borderless],
            backing: .buffered,
            defer: false
        )
        
        self.delegate = _delegate
        self.title = "NilWindow"
        self.isReleasedWhenClosed = false
        
        self.contentView = NSView()
        self.setIsVisible(true)
    }
}

class NilWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        return NSSize(width: 1, height: 1)
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return false
    }
}
