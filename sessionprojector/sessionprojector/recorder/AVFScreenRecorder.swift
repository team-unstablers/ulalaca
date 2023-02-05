//
// Created by Gyuhwan Park on 2022/07/04.
//

import Foundation

import CoreGraphics
import CoreImage
import VideoToolbox
import AVFoundation

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

    private var currentScreenResolution = CGSize(width: 0, height: 0)

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
        subscriber.screenResolutionChanged(to: self.currentScreenResolution)
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
            fatalError("")
        }

        captureSession.beginConfiguration()

        screenInput.capturesCursor = true

        captureOutput.setSampleBufferDelegate(self, queue: streamQueue)
        captureOutput.videoSettings = [
            (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
        ]

        if (!captureSession.canAddInput(screenInput)) {
            fatalError("")
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
        if (frameSize != self.currentScreenResolution) {
            logger.debug("resolution changed to \(frameSize)")
            self.currentScreenResolution = frameSize

            subscriptions.forEach { subscriber in
                subscriber.screenResolutionChanged(to: frameSize)
            }
        }


        let contentRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        subscriptions.forEach { $0.screenUpdated(where: contentRect) }
        subscriptions.forEach { subscriber in
            if (!subscriber.suppressOutput) {
                notifyScreenReady(which: sampleBuffer, rect: contentRect, to: subscriber)
            }
        }
    }

    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }

    /**
     FIXME: duplicated code
     */
    func notifyScreenReady(which sampleBuffer: CMSampleBuffer, rect: CGRect, to subscriber: ScreenUpdateSubscriber) {
        var image: CGImage?

        if let viewportInfo = subscriber.mainViewport {
            let pixelBuffer = sampleBuffer.resize(size: viewportInfo.toCGSize(), context: ciContext)
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            subscriber.screenReady(image: image!, rect: CGRect(x: 0, y: 0, width: Int(viewportInfo.width), height: Int(viewportInfo.height)))
        } else {
            CVPixelBufferLockBaseAddress(sampleBuffer.imageBuffer!, .readOnly)
            VTCreateCGImageFromCVPixelBuffer(sampleBuffer.imageBuffer!, options: nil, imageOut: &image)
            CVPixelBufferUnlockBaseAddress(sampleBuffer.imageBuffer!, .readOnly)
            subscriber.screenReady(image: image!, rect: rect)
        }
    }

}

