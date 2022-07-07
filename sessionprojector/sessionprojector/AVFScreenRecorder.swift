//
// Created by Gyuhwan Park on 2022/07/04.
//

import Foundation

import CoreGraphics
import VideoToolbox
import AVFoundation

class AVFScreenRecorder: NSObject, ScreenRecorder {
    private var streamQueue = DispatchQueue(
            label: "UlalacaAVFStreamRecorder",
            qos: .userInteractive
    )

    private var captureSession = AVCaptureSession()

    private var screenInput: AVCaptureScreenInput? = nil
    private var captureOutput: AVCaptureVideoDataOutput? = nil

    private var subscriptions: [ScreenUpdateSubscriber] = []
    private var prevDisplayTime: UInt64 = 0

    override init() {
        super.init()
    }

    func subscribeUpdate(_ subscriber: ScreenUpdateSubscriber) {
        let isExists = subscriptions.filter { $0.identifier == subscriber.identifier }.first != nil
        if (isExists) {
            return
        }

        subscriptions.append(subscriber)
    }

    func unsubscribeUpdate(_ subscriber: ScreenUpdateSubscriber) {
        guard let index = subscriptions.firstIndex(where: {
            $0.identifier == subscriber.identifier
        }) else { return }

        subscriptions.remove(at: index)
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


        let now = CMTime(value: Int64(mach_absolute_time()), timescale: 1000000000)
        let frameTimestamp = sampleBuffer.presentationTimeStamp

        let timedelta = abs(now.seconds - frameTimestamp.seconds)


        let contentRect = CGRect(x: 0, y: 0, width: image!.width, height: image!.height)
        subscriptions.forEach { $0.screenUpdated(where: contentRect) }
        subscriptions.forEach { $0.screenReady(image: image!, rect: contentRect) }
    }

    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }
}

