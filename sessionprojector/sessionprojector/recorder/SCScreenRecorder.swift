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

    private var currentScreenResolution = CGSize(width: 0, height: 0)

    private var nilWindow: NilWindow? = nil
    // HACK
    private var this: SCScreenRecorder!

    private var streamQueue = DispatchQueue(
            label: "UlalacaStreamRecorder",
            qos: .background
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
        self.nilWindow = await NilWindow()
        
        let configuration = SCStreamConfiguration()
        let autoFramerate = AppState.instance
                .userPreferences
                .autoFramerate
        let frameRate = AppState.instance
                .userPreferences
                .framerate

        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.queueDepth = 1
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

            // since macOS 12.3↑, passing empty array to excludingWindows breaks SCStream
            let filter = SCContentFilter(
                    display: primaryDisplay,
                    excludingApplications: [],
                    exceptingWindows: [nilWindowHandle]
            )

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
        do {
            try await stream!.startCapture()
        } catch {
            throw ScreenRecorderError.streamStartFailure
        }
    }

    func stop() async throws {
        try await stream!.stopCapture()
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

        if (frameInfo.contentRect!.size != self.currentScreenResolution) {
            logger.debug("resolution changed to \(frameInfo.contentRect!.size)")
            self.currentScreenResolution = frameInfo.contentRect!.size

            subscriptions.forEach { subscriber in
                subscriber.screenResolutionChanged(to: frameInfo.contentRect!.size)
            }
        }

        let now = CMTime(value: Int64(mach_absolute_time()), timescale: 1000000000)
        let frameTimestamp = sampleBuffer.presentationTimeStamp

        let timedelta = abs(now.seconds - frameTimestamp.seconds)

        if let dirtyRects = frameInfo.dirtyRects {
            subscriptions.forEach { subscriber in
                dirtyRects.forEach { rect in
                    subscriber.screenUpdated(where: rect)
                }
            }

            subscriptions.forEach { subscriber in
                if (!subscriber.suppressOutput) {
                    notifyScreenReady(which: sampleBuffer, rect: frameInfo.contentRect!, to: subscriber)
                }
            }
        }
    }

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

