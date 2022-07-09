//
// Created by Gyuhwan Park on 2022/07/04.
//

import Foundation

import CoreGraphics
import VideoToolbox
import ScreenCaptureKit

fileprivate struct FrameInfo {
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

class SCScreenRecorder: NSObject, ScreenRecorder {
    private var streamQueue = DispatchQueue(
            label: "UlalacaStreamRecorder",
            qos: .userInteractive
    )

    private var stream: SCStream?
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
        let configuration = SCStreamConfiguration()

        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.queueDepth = 1
        configuration.showsCursor = true

        let displays = try await SCShareableContent.current.displays
        guard let primaryDisplay = displays.first else {
            throw ScreenRecorderError.initializationError
        }

        configuration.width = primaryDisplay.width
        configuration.height = primaryDisplay.height

        let filter = SCContentFilter(display: primaryDisplay, excludingWindows: [])

        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        guard let stream = stream else {
            throw ScreenRecorderError.initializationError
        }

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: streamQueue)
    }

    func start() async throws {
        do {
            try await stream!.startCapture()
        } catch {
            throw ScreenRecorderError.streamStartFailure
        }
    }

    func stop() throws {

    }
}

extension SCScreenRecorder: SCStreamDelegate {
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        print(error.localizedDescription)
    }
}

extension SCScreenRecorder: SCStreamOutput {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let frameInfo = FrameInfo(from: sampleBuffer) else {
            return
        }

        if (frameInfo.status != .complete) {
            return
        }

        if (subscriptions.count == 0) {
            return
        }

        var image: CGImage?
        VTCreateCGImageFromCVPixelBuffer(sampleBuffer.imageBuffer!, options: nil, imageOut: &image)
        CVPixelBufferUnlockBaseAddress(sampleBuffer.imageBuffer!, .readOnly)


        let now = CMTime(value: Int64(mach_absolute_time()), timescale: 1000000000)
        let frameTimestamp = sampleBuffer.presentationTimeStamp

        let timedelta = abs(now.seconds - frameTimestamp.seconds)

        if let dirtyRects = frameInfo.dirtyRects {
            dirtyRects.forEach { rect in
                subscriptions.forEach { $0.screenUpdated(where: rect) }
            }
        }
        subscriptions.forEach { $0.screenReady(image: image!, rect: frameInfo.contentRect!) }
    }
}

