

import Foundation
import UIKit
import AVFoundation

final class PhotoHandlerFactory {
    static func makeHandler(
        config: CameraViewModel.Configuration,
        onProcessed: @escaping (UIImage?) -> Void,
        onProcessingStateChanged: @escaping (Bool) -> Void
    ) -> PhotoCaptureHandler {
        let processor = CapturedImageProcessor(config: config)
        return PhotoCaptureHandler(
            processor: processor,
            onProcessed: onProcessed,
            onProcessingStateChanged: onProcessingStateChanged
        )
    }
}

