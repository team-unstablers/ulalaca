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

    private var ciContext: CIContext

    private var stream: SCStream?
    private var subscriptions: [ScreenUpdateSubscriber] = []
    private var prevDisplayTime: UInt64 = 0


    private var streamQueue = DispatchQueue(
            label: "UlalacaStreamRecorder",
            qos: .userInteractive
    )

    private static func createCoreImageContext(useMetal: Bool = true) -> CIContext {
        staticLogger.debug("creating CIContext")

        if let ciContext = NSGraphicsContext.current?.ciContext {
            staticLogger.debug("acquired CIContext from NSGraphicsContext.current")
            return ciContext
        }

        if (useMetal) {
            if let metalDevice = MTLCreateSystemDefaultDevice() {
                staticLogger.debug("created CIContext using Metal API")
                return CIContext(mtlDevice: metalDevice)
            }
        }

        if let cgContext = NSGraphicsContext.current?.cgContext {
            staticLogger.debug("created CIContext using cgContext")
            return CIContext(cgContext: cgContext)
        } else {
            staticLogger.error("creating CIContext using software renderer, this will impact performance (is hardware acceleration available?)")
            return CIContext(options: [
                .useSoftwareRenderer: true
            ])
        }
    }

    override init() {
        super.init()

        self.ciContext = SCScreenRecorder.createCoreImageContext(useMetal: true)
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

        let now = CMTime(value: Int64(mach_absolute_time()), timescale: 1000000000)
        let frameTimestamp = sampleBuffer.presentationTimeStamp

        let timedelta = abs(now.seconds - frameTimestamp.seconds)

        if let dirtyRects = frameInfo.dirtyRects {
            dirtyRects.forEach { rect in
                subscriptions.forEach { $0.screenUpdated(where: rect) }
            }
        }
        subscriptions.forEach { subscriber in
            notifyScreenReady(which: sampleBuffer, rect: frameInfo.contentRect!, to: subscriber)
        }
    }

    func notifyScreenReady(which sampleBuffer: CMSampleBuffer, rect: CGRect, to subscriber: ScreenUpdateSubscriber) {
        var image: CGImage?

        if let viewportInfo = subscriber.mainDisplay {
            let pixelBuffer = sampleBuffer.resize(size: viewportInfo.toCGSize(), context: ciContext)
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
            subscriber.screenReady(image: image, rect: CGRect(0, 0, Int(viewportInfo.width), Int(viewportInfo.height)))
        } else {
            VTCreateCGImageFromCVPixelBuffer(sampleBuffer.imageBuffer!, options: nil, imageOut: &image)
            subscriber.screenReady(image: image, rect: rect)
        }

    }
}

fileprivate extension CMSampleBuffer {
    func resize(size desiredSize: CGSize, context: CIContext) -> CVPixelBuffer {
        let imageBuffer = self.imageBuffer!

        let outPixelBuffer: CVPixelBuffer? = nil
        let result = CVPixelBufferCreate(
            nil,
            Int(desiredSize.width), Int(desiredSize.height),
            CVPixelBufferGetPixelFormatType(imageBuffer),
            nil,
            &outPixelBuffer
        )

        let size = CVImageBufferGetEncodedSize(imageBuffer)
        let ciImage = CIImage(cvImageBuffer: imageBuffer)

        let sx = CGFloat(desiredSize.width) / CGFloat(size.width)
        let sy = CGFloat(desiredSize.height) / CGFloat(size.height)

        let scale = CGAffineTransform(scaleX: sx, y: sy)
        let scaledImage = ciImage.transformed(by: scale)
        context.render(scaledImage, to: outPixelBuffer)

        return outPixelBuffer!
    }
}
