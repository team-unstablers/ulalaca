//
// Created by Gyuhwan Park on 2022/04/13.
//

import Foundation

import CoreGraphics
import VideoToolbox
import ScreenCaptureKit

import UlalacaCore

enum ScreenRecorderError: LocalizedError {
    case unknown

    case insufficientPermission
    case initializationError(reason: String)
    case streamStartFailure

    var errorDescription: String? {
        switch (self) {
        case .unknown:
            return "Unknown error."

        case .insufficientPermission:
            return """
                   Insufficient permission to record screen.

                   Note to developers: If you are building this app from source code, please choose one of the following options:

                   - Sign this app with a valid Developer ID certificate 
                   - Remove and re-add this app from the list of apps that can record screen on every build

                   If you already granted permission to record screen, Please remove and re-add this app from the list of apps that can record screen.
                   """

        case .initializationError(let reason):
            return "Could not initialize ScreenRecorder instance:\n\(reason)"

        case .streamStartFailure:
            return "Failed to start recording stream. (insufficient permission?)"
        }
    }
}

struct ViewportInfo {
    var width: UInt16
    var height: UInt16

    func scaleX(_ value: IntegerLiteralType) -> Double {
        if (value <= 0) {
            return 0.0
        }

        return Double(width) / Double(value);
    }
    func scaleY(_ value: IntegerLiteralType) -> Double {
        if (value <= 0) {
            return 0.0
        }

        return Double(height) / Double(value);
    }

    func toCGSize() -> CGSize {
        CGSize(width: Int(width), height: Int(height))
    }
}

protocol ScreenUpdateSubscriber {
    var identifier: Int {
        get
    }

    var suppressOutput: Bool {
        get
    }

    var mainViewport: ViewportInfo {
        get
    }

    /**
     Called when the area of screen marked as dirty.
     - Parameter rect: dirty area
     - Note: implementation of ScreenRecorder should pass `rect` scaled to the main viewport.
     */
    func screenUpdated(where rect: CGRect)

    /**
     Called when screen capture is ready.
     - Parameters:
       - image: content of screen
       - rect: area of screen captured
     - Note: implementation of ScreenRecorder should pass `image` / `rect` scaled to the main viewport.
     */
    func screenReady(image: CGImage, rect: CGRect)

    /**
     Called when screen resolution is changed.
     - Parameters:
       - resolution: new screen resolution
       - scaleFactor: scale factor (e.g. 2.0 for Retina display)
     */
    func screenResolutionChanged(to resolution: CGSize, scaleFactor: Double)
}

protocol ScreenRecorderDelegate {
    func screenRecorder(didStopWithError error: Error)
}

protocol ScreenRecorder: NSObject {
    var delegate: ScreenRecorderDelegate? { get set }

    func subscribeUpdate(_ subscriber: ScreenUpdateSubscriber)
    func unsubscribeUpdate(_ subscriber: ScreenUpdateSubscriber)

    func moveSubscribers(to other: ScreenRecorder)

    func prepare() async throws
    func start() async throws
    func stop() async throws
}

/**
 selects/returns appropriate screen recorder type

 - Parameters:
   - recorderType: preferred recorder type (but no guarantee)
   - isScreenLocked: isScreenLocked
   - isLoginSession: is uid == 0 (loginwindow)
 - Returns:
 */
func createScreenRecorder(
    preferred recorderType: ScreenRecorderType,
    isScreenLocked: Bool,
    isLoginSession: Bool
) -> ScreenRecorder {
    if (isLoginSession || isScreenLocked) {
        return AVFScreenRecorder()
    }

    switch (recorderType) {
    case .avfScreenRecorder:
        return AVFScreenRecorder()
    case .scScreenRecorder:
        return SCScreenRecorder()
    }
}
