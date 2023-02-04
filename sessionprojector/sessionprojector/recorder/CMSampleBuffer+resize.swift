//
// Created by Gyuhwan Park on 2023/02/04.
//

import Foundation

import CoreMedia
import CoreImage

extension CMSampleBuffer {
    func resize(size desiredSize: CGSize, context: CIContext) -> CVPixelBuffer {
        let imageBuffer = self.imageBuffer!

        var outPixelBuffer: CVPixelBuffer? = nil
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
        context.render(scaledImage, to: outPixelBuffer!)

        return outPixelBuffer!
    }
}
