

import Foundation
import CoreGraphics

struct CameraConfiguration {
    var captureInterval: TimeInterval = 2.0
    var blurRadius: CGFloat = 30
    var preserveFaceWithoutBlur: Bool = true 
    var maxImageDimension: CGFloat = 640
    var confidenceThreshold: Float = 0.3
    var processingFPS: Int = 10
}
