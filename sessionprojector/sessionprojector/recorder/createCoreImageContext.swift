//
// Created by Gyuhwan Park on 2023/02/04.
//

import Foundation

import UlalacaCore

import ScreenCaptureKit
import CoreGraphics
import CoreImage

func createCoreImageContext(useMetal: Bool = true) -> CIContext {
    let logger = createLogger("createCoreImageContext")

    logger.debug("creating CIContext")

    if let ciContext = NSGraphicsContext.current?.ciContext {
        logger.debug("acquired CIContext from NSGraphicsContext.current")
        return ciContext
    }

    if (useMetal) {
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            logger.debug("created CIContext using Metal API")
            return CIContext(mtlDevice: metalDevice)
        }
    }

    if let cgContext = NSGraphicsContext.current?.cgContext {
        logger.debug("created CIContext using cgContext")
        return CIContext(cgContext: cgContext)
    } else {
        logger.error("creating CIContext using software renderer, this will impact performance (is hardware acceleration available?)")
        return CIContext(options: [
            .useSoftwareRenderer: true
        ])
    }
}
