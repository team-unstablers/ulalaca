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

    case initializationError(reason: String)
    case streamStartFailure

    var errorDescription: String? {
        switch (self) {
        case .unknown:
            return "unknown error"

        case .initializationError(let reason):
            return "could not initialize ScreenCaptureKit stream: \(reason)"

        case .streamStartFailure:
            return "failed to start ScreenCaptureKit stream (insufficient permission?)"
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

    var mainViewport: ViewportInfo? {
        get
    }

    func screenUpdated(where rect: CGRect)
    func screenReady(image: CGImage, rect: CGRect)
    func screenResolutionChanged(to resolution: CGSize)
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
