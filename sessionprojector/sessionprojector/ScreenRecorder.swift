//
// Created by Gyuhwan Park on 2022/04/13.
//

import Foundation

import CoreGraphics
import VideoToolbox
import ScreenCaptureKit

enum ScreenRecorderError: LocalizedError {
    case unknown

    case initializationError
    case streamStartFailure

    var errorDescription: String? {
        switch (self) {
        case .unknown:
            return "unknown error"

        case .initializationError:
            return "could not initialize ScreenCaptureKit stream"

        case .streamStartFailure:
            return "failed to start ScreenCaptureKit stream (insufficient permission?)"
        }
    }
}

protocol ScreenUpdateSubscriber {
    var identifier: Int {
        get
    }

    func screenUpdated(where rect: CGRect)
    func screenReady(image: CGImage, rect: CGRect)
    func screenResolutionChanged(to resolution: (Int, Int))
}

protocol ScreenRecorder: NSObject {
    func subscribeUpdate(_ subscriber: ScreenUpdateSubscriber)
    func unsubscribeUpdate(_ subscriber: ScreenUpdateSubscriber)

    func prepare() async throws
    func start() async throws
    func stop() async throws
}


func createScreenRecorder() -> ScreenRecorder {
    if (getuid() == 0) {
        // root (loginwindow)
        return AVFScreenRecorder()
    } else {
        return SCScreenRecorder()
    }
}