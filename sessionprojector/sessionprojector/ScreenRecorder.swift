//
// Created by Gyuhwan Park on 2022/04/13.
//

import Foundation

import CoreGraphics
import AVFoundation
import ScreenCaptureKit

enum ScreenRecorderError: Error {
    case unknownError
    case initializationError

}

struct FrameInfo {
    init?(from sampleBuffer: CMSampleBuffer) {
        let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: true
        ) as? [[SCStreamFrameInfo: Any]]
        guard let attachments = attachmentsArray?.first else {
            return nil
        }

        guard let rawStatus = attachments[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus) else {
            return nil
        }

        self.status = status
        displayTime = attachments[.displayTime] as? UInt64
        scaleFactor = attachments[.scaleFactor] as? Double
        contentScale = attachments[.contentScale] as? Double
        if let contentRectDict = attachments[.contentRect] as? NSDictionary {
            contentRect = CGRect(dictionaryRepresentation: contentRectDict)
        }
        if let dirtyRectsDict = attachments[.dirtyRects] as? [NSDictionary] {
            dirtyRects = dirtyRectsDict.compactMap { CGRect(dictionaryRepresentation: $0) }
        }
    }

    var status: SCFrameStatus
    var displayTime: UInt64?
    var scaleFactor: Double?
    var contentScale: Double?
    var contentRect: CGRect?
    var dirtyRects: [CGRect]?
}

protocol ScreenUpdateSubscriber {
    func screenUpdated(_ image: CIImage, where rect: CGRect)
    func screenResolutionChanged(to resolution: (Int, Int))
}

class ScreenRecorder: NSObject {
    private var captureSession = AVCaptureSession()
    private var streamQueue = DispatchQueue(
        label: "UlalacaStreamRecorder",
        qos: .userInteractive
    )

    private let screenInput: AVCaptureScreenInput
    private let output: AVCaptureVideoDataOutput

    private var stream: SCStream?
    private var subscriptions: [ScreenUpdateSubscriber] = []

    override init() {

        // TODO: 다중 디스플레이 지원하려면 list로 바꾸거나 해야 할지도
        screenInput = AVCaptureScreenInput()

        output = AVCaptureVideoDataOutput()

        super.init()
    }

    func prepare() async throws {
        let configuration = SCStreamConfiguration()

        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(45))
        configuration.queueDepth = 4
        configuration.showsCursor = false

        let displays = try! await SCShareableContent.current.displays
        guard let primaryDisplay = displays.first else {
            throw ScreenRecorderError.initializationError
        }
        let filter = SCContentFilter(display: primaryDisplay, excludingWindows: [])

        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        guard let stream = stream else {
            throw ScreenRecorderError.initializationError
        }

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: streamQueue)
    }

    func start() async throws {
        try await stream!.startCapture()
    }

    func stop() throws {

    }
}

extension ScreenRecorder: SCStreamDelegate {
    public func stream(_ stream: SCStream, didStopWithError error: Error) {

    }
}

extension ScreenRecorder: SCStreamOutput {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let frameInfo = FrameInfo(from: sampleBuffer) else {
            return
        }

        if (frameInfo.status != .complete) {
            // not ready to draw
            return
        }

        let pixelBuffer = sampleBuffer.imageBuffer
        guard let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            return
        }

        let image = CIImage(ioSurface: surfaceRef)

        if let dirtyRects = frameInfo.dirtyRects {
            dirtyRects.forEach { rect in
                print("updating dirty rects: \(rect)")
                publishScreenUpdate(image.cropped(to: rect), where: rect)
            }
        } else {
            print("updating entire screen")
            publishScreenUpdate(image, where: frameInfo.contentRect!)
        }
    }

    func publishScreenUpdate(_ image: CIImage, where rect: CGRect) {
        subscriptions.forEach { $0.screenUpdated(image, where: rect) }
    }
}

extension ScreenRecorder: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("caputreOutput:didOutput called: \(sampleBuffer)")
    }

    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }
}