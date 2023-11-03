//
// Created by Gyuhwan Park on 2022/07/04.
//

import Foundation

import CoreGraphics
import VideoToolbox
import ScreenCaptureKit

import UlalacaCore

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
    private static let staticLogger = createLogger("SCScreenRecorder::*")
    private let logger = createLogger("SCScreenRecorder")

    public var delegate: ScreenRecorderDelegate? = nil
    public let delegateQueue = DispatchQueue(label: "SCScreenRecorderDelegateQueue")

    private var ciContext: CIContext

    private var stream: SCStream?
    private var subscriptions: [ScreenUpdateSubscriber] = []
    private var prevDisplayTime: UInt64 = 0

    /**
     non-scaled (1x) screen resolution
     (1920x1080@1x) => 1920x1080
     (1920x1080@2x) => 1920x1080
     */
    private(set) public var frameSize: CGSize = .zero
    private(set) public var scaleFactor: CGFloat = 1.0

    private var nilWindow: NilWindow? = nil
    // HACK
    private var this: SCScreenRecorder!

    private var streamQueue = DispatchQueue(
            label: "UlalacaStreamRecorder",
            qos: .userInteractive
    )

    override init() {
        self.ciContext = createCoreImageContext(useMetal: true)
        super.init()

        self.this = self
        self.listenToDisplayConfigurationChange()
    }

    private func listenToDisplayConfigurationChange() {
        CGDisplayRegisterReconfigurationCallback({ display, flags, userInfo in
            let this = userInfo!.bindMemory(to: SCScreenRecorder.self, capacity: 1).pointee

            Task {
                try? await this.stop()
                try! await this.prepare()
                try! await this.start()
            }
        }, &this)
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
        self.nilWindow = await NilWindow()
        
        let configuration = SCStreamConfiguration()
        let autoFramerate = AppState.instance
                .userPreferences
                .autoFramerate
        let frameRate = AppState.instance
                .userPreferences
                .framerate

        configuration.pixelFormat = kCVPixelFormatType_32BGRA

        if #available (macOS 14.0, *) {
            // in macOS 14.0↑, setting queueDepth to 1 breaks SCStream.
            // SCStreamOutput::stream(:didOutputSampleBuffer:...) will be called only once
            configuration.queueDepth = 4    
        } else {
            configuration.queueDepth = 1
        }

        configuration.showsCursor = true

        if (!autoFramerate) {
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(Int(frameRate)))
        }

        do {
            let displays = try await SCShareableContent.current.displays
            let nilWindowID = await nilWindow!.windowNumber
            guard let nilWindowHandle = try? await SCShareableContent.current.windows.filter { window in
                return window.windowID == nilWindowID
            }.first else {
                throw ScreenRecorderError.initializationError(reason: "Could not acquire nilWindow handle: the 1x1-sized dummy window is required to capture the entire screen.")
            }

            guard let primaryDisplay = displays.first else {
                throw ScreenRecorderError.initializationError(reason: "primary display is not available.")
            }


            configuration.width = primaryDisplay.width
            configuration.height = primaryDisplay.height

            var filter = SCContentFilter(
                display: primaryDisplay,
                excludingWindows: []
            )
            
            if #available(macOS 14.0, *) {
                filter = SCContentFilter(
                    display: primaryDisplay,
                    excludingWindows: []
                )
            } else if #available(macOS 12.3, *) {
                // since macOS 12.3↑, passing empty array to excludingWindows breaks SCStream
                filter = SCContentFilter(
                    display: primaryDisplay,
                    excludingApplications: [],
                    exceptingWindows: [nilWindowHandle]
                )
            }

            stream = SCStream(filter: filter, configuration: configuration, delegate: self)
            guard let stream = stream else {
                throw ScreenRecorderError.initializationError(reason: "Could not open SCStream.")
            }

            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: streamQueue)
        } catch let error as SCStreamError {
            if (error.localizedDescription.contains("declined TCCs")) {
                throw ScreenRecorderError.insufficientPermission
            }
            throw ScreenRecorderError.initializationError(reason: "caught SCStreamError: \(error.localizedDescription)")
        }
    }

    func start() async throws {
        guard let stream = self.stream else {
            throw ScreenRecorderError.streamStartFailure
        }
        
        do {
            try await stream.startCapture()
        } catch {
            throw ScreenRecorderError.streamStartFailure
        }
    }

    func stop() async throws {
        guard let stream = self.stream else {
            return
        }
        
        try await stream.stopCapture()
    }
}

extension SCScreenRecorder: SCStreamDelegate {
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("didStopWithError: \(error.localizedDescription)")

        delegateQueue.async {
            self.delegate?.screenRecorder(didStopWithError: error)
        }
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

        let frameSize = CVImageBufferGetEncodedSize(sampleBuffer.imageBuffer!)
        let scaleFactor = frameInfo.scaleFactor ?? 1.0

        if (frameSize != self.frameSize || scaleFactor != self.scaleFactor) {
            logger.debug("screen resolution changed to \(frameSize) @ \(scaleFactor)x")

            self.frameSize = frameSize
            self.scaleFactor = scaleFactor

            subscriptions.forEach { subscriber in
                subscriber.screenResolutionChanged(to: frameSize, scaleFactor: scaleFactor)
            }
        }

        let now = CMTime(value: Int64(mach_absolute_time()), timescale: 1000000000)
        let frameTimestamp = sampleBuffer.presentationTimeStamp

        let timedelta = abs(now.seconds - frameTimestamp.seconds)

        if let dirtyRects = frameInfo.dirtyRects {
            subscriptions.forEach { subscriber in
                let sx = CGFloat(subscriber.mainViewport.width)  / self.frameSize.width
                let sy = CGFloat(subscriber.mainViewport.height) / self.frameSize.height

                dirtyRects.forEach { rect in
                    subscriber.screenUpdated(where: rect.scale(sx: sx, sy: sy))
                }
            }

            subscriptions.forEach { subscriber in
                if (!subscriber.suppressOutput) {
                    notifyScreenReady(which: sampleBuffer, to: subscriber)
                }
            }
        }
    }

    func notifyScreenReady(which sampleBuffer: CMSampleBuffer, to subscriber: ScreenUpdateSubscriber) {
        var image: CGImage?

        let frameSize = CVImageBufferGetEncodedSize(sampleBuffer.imageBuffer!)
        let frameRect = CGRect(x: 0, y: 0, width: frameSize.width, height: frameSize.height)

        let viewport = subscriber.mainViewport

        let sx = CGFloat(viewport.width)  / self.frameSize.width
        let sy = CGFloat(viewport.height) / self.frameSize.height

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

