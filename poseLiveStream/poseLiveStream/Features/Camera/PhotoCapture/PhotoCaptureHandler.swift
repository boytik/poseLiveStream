

import AVFoundation
import UIKit

final class PhotoCaptureHandler: NSObject, AVCapturePhotoCaptureDelegate {
    private let processor: CapturedImageProcessor
    private let onProcessed: (UIImage?) -> Void
    private let onProcessingStateChanged: (Bool) -> Void

    init(
        processor: CapturedImageProcessor,
        onProcessed: @escaping (UIImage?) -> Void,
        onProcessingStateChanged: @escaping (Bool) -> Void
    ) {
        self.processor = processor
        self.onProcessed = onProcessed
        self.onProcessingStateChanged = onProcessingStateChanged
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            onProcessingStateChanged(false)
            return
        }

        onProcessingStateChanged(true)

        DispatchQueue.global(qos: .userInitiated).async {
            let processed = self.processor.process(image: image)

            DispatchQueue.main.async {
                self.onProcessed(processed)
                self.onProcessingStateChanged(false)
            }
        }
    }
}

