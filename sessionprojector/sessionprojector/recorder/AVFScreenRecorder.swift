//
// Created by Gyuhwan Park on 2022/07/04.
//

import Foundation

import CoreGraphics
import CoreImage
import VideoToolbox
import AVFoundation

import AppKit

import UlalacaCore

class AVFScreenRecorder: NSObject, ScreenRecorder {
    private let logger = createLogger("AVFScreenRecorder")

    private var streamQueue = DispatchQueue(
            label: "UlalacaAVFStreamRecorder",
            qos: .userInteractive
    )

    public var delegate: ScreenRecorderDelegate? = nil

    private var ciContext: CIContext

    private var captureSession = AVCaptureSession()

    private var screenInput: AVCaptureScreenInput? = nil
    private var captureOutput: AVCaptureVideoDataOutput? = nil

    private var subscriptions: [ScreenUpdateSubscriber] = []
    private var prevDisplayTime: UInt64 = 0

    /**
     screen resolution
     (1920x1080@1x) => 1920x1080
     (1920x1080@2x) => 3840x2160

     Note: AVFoundation returns scaled resolution, so we need to divide it by scale factor.
     */
    private(set) public var frameSize: CGSize = .zero
    private(set) public var scaleFactor: Double = 1.0

    override init() {
        self.ciContext = createCoreImageContext(useMetal: true)
        super.init()
    }

    func subscribeUpdate(_ subscriber: ScreenUpdateSubscriber) {
        let isExists = subscriptions.filter { $0.identifier == subscriber.identifier }.first != nil
        if (isExists) {
            return
        }

        subscriptions.append(subscriber)
        subscriber.screenResolutionChanged(to: self.frameSize, scaleFactor: self.scaleFactor)
    }

    func unsubscribeUpdate(_ subscriber: ScreenUpdateSubscriber) {
        guard let index = subscriptions.firstIndex(where: {
            $0.identifier == subscriber.identifier
        }) else { return }

        subscriptions.remove(at: index)
    }

    func moveSubscribers(to other: ScreenRecorder) {
        let subscriptions = Array<ScreenUpdateSubscriber>(self.subscriptions)

        subscriptions.forEach { subscriber in
            self.unsubscribeUpdate(subscriber)
            other.subscribeUpdate(subscriber)
        }
    }

    func prepare() async throws {
        screenInput = AVCaptureScreenInput()
        captureOutput = AVCaptureVideoDataOutput()

        guard let screenInput = screenInput,
              let captureOutput = captureOutput else {
            throw ScreenRecorderError.streamStartFailure
        }

        captureSession.beginConfiguration()

        /*
        let autoFramerate = AppState.instance
                .userPreferences
                .autoFramerate
        let frameRate = AppState.instance
                .userPreferences
                .framerate
         */

        screenInput.capturesCursor = true
        screenInput.removesDuplicateFrames = true

        /*
        if (autoFramerate) {
            screenInput.minFrameDuration = CMTime(value: 1, timescale: CMTimeScale(Int(frameRate)))
        }
         */

        captureOutput.alwaysDiscardsLateVideoFrames = true

        captureOutput.setSampleBufferDelegate(self, queue: streamQueue)
        captureOutput.videoSettings = [
            (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA,
        ]

        if (!captureSession.canAddInput(screenInput)) {
            throw ScreenRecorderError.streamStartFailure
        }
        captureSession.addInput(screenInput)
        captureSession.addOutput(captureOutput)

        captureSession.commitConfiguration()
    }

    func start() async throws {
        do {
            try captureSession.startRunning()
        } catch {
            throw ScreenRecorderError.streamStartFailure
        }
    }

    func stop() throws {
        captureSession.stopRunning()
    }

    func queryScreenResolution() -> CGSize {
        guard let primaryScreen = NSScreen.main else {
            return .zero
        }

        return primaryScreen.frame.size
    }
}

extension AVFScreenRecorder: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if (subscriptions.count == 0) {
            return
        }

        var image: CGImage?

        VTCreateCGImageFromCVPixelBuffer(sampleBuffer.imageBuffer!, options: nil, imageOut: &image)
        CVPixelBufferUnlockBaseAddress(sampleBuffer.imageBuffer!, .readOnly)

        guard let image = image else { return }

        let now = CMTime(value: Int64(mach_absolute_time()), timescale: 1000000000)
        let frameTimestamp = sampleBuffer.presentationTimeStamp

        let timedelta = abs(now.seconds - frameTimestamp.seconds)

        let frameSize = CGSize(width: image.width, height: image.height)
        if (frameSize != self.frameSize) {
            let actual = self.queryScreenResolution()
            let scaleFactor = CGFloat(frameSize.width) / actual.width

            logger.debug("screen resolution changed to \(frameSize) @ \(scaleFactor)x")

            self.frameSize = frameSize
            self.scaleFactor = scaleFactor

            subscriptions.forEach { subscriber in
                subscriber.screenResolutionChanged(to: actual, scaleFactor: scaleFactor)
            }
        }


        let contentRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        subscriptions.forEach { subscriber in
            let sx = CGFloat(subscriber.mainViewport.width)  / self.frameSize.width
            let sy = CGFloat(subscriber.mainViewport.height) / self.frameSize.height

            subscriber.screenUpdated(where: contentRect.scale(sx: sx, sy: sy))
        }
        subscriptions.forEach { subscriber in
            if (!subscriber.suppressOutput) {
                notifyScreenReady(which: sampleBuffer, to: subscriber)
            }
        }
    }

    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }

    /**
     FIXME: duplicated code
     */
    func notifyScreenReady(which sampleBuffer: CMSampleBuffer, to subscriber: ScreenUpdateSubscriber) {
        var image: CGImage?

        let frameSize = CVImageBufferGetEncodedSize(sampleBuffer.imageBuffer!)
        let frameRect = CGRect(x: 0, y: 0, width: Int(frameSize.width), height: Int(frameSize.height))

        let viewport = subscriber.mainViewport

        let sx = CGFloat(subscriber.mainViewport.width)  / self.frameSize.width
        let sy = CGFloat(subscriber.mainViewport.height) / self.frameSize.height

        if (sx != 1.0 || sy != 1.0) {
            let pixelBuffer = sampleBuffer.resize(size: viewport.toCGSize(), context: ciContext)
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            subscriber.screenReady(image: image!, rect: frameRect.scale(sx: sx, sy: sy))
        } else {
            CVPixelBufferLockBaseAddress(sampleBuffer.imageBuffer!, .readOnly)
            VTCreateCGImageFromCVPixelBuffer(sampleBuffer.imageBuffer!, options: nil, imageOut: &image)
            CVPixelBufferUnlockBaseAddress(sampleBuffer.imageBuffer!, .readOnly)
            subscriber.screenReady(image: image!, rect: frameRect)
        }
    }

}

